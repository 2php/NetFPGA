/* 
 * A user-level program to compute RCP's rate.
 * Authors: Nandita Dukkipati (nanditad@stanfordalumni.org) and Jiang Zhu (jiangzhu@stanford.edu)
 * Date: 20 October, 2008
 * Algorithm first described in: 
 * "Processor Sharing Flows in the Internet"
 * Nandita Dukkipati, Masayoshi Kobayashi, Rui Zhang-Shen and Nick McKeown
 * Thirteenth International Workshop on Quality of Service (IWQoS), Passau, Germany, June 2005.
 *
 * RCP Equation:
 * R = R * { 1 + (T/avg_rtt)*[alpha*(gamma*C - input_tr/T) - beta*Q/avg_rtt]/gamma*C};
 * where:
 * R: RCP rate in Bytes/msec.
 * C: link-capacity in Bytes/msec.
 * input_tr: input-traffic (in Bytes) measured over the interval 'T' msec.
 * alpha, beta, gamma: constants
 * avg_rtt: average round-trip time in msec. 
 * T = min(10ms, avg_rtt)
 * Q: queue length in Bytes
 */

#include <math.h>
#include <string.h>
#include <stdio.h> 
#include <signal.h> 
#include <sys/time.h> 
#include <stdlib.h>

#include "nf2util.h"
#include "reg_defines.h"

struct nf2device nf2;

void connectnf2() {
  nf2.device_name = DEFAULT_IFACE;
  check_iface( &nf2 );
  if( openDescriptor( &nf2 ) != 0 ) {
    printf( "Error: failed to connect to the hardware\n" );
    exit(1);
  }
/* wait for the reset to complete */
  struct timespec pause;
  pause.tv_sec = 0;
  pause.tv_nsec = 5000 * 1000; /* 5ms */
  nanosleep( &pause, NULL );

}
/* -------------- Constants ------------- */

#define ALPHA 0.4
#define BETA 0.5
#define GAMMA 0.95

#define INIT_RATE_FACT 0.05 
#define RTT 200 // msec
#define TIMESLOT 10 // msec
#define RTT_GAIN 0.02 
#define PKTSIZE 1500

#define RCP_MAC_COUNT 4
#define RCP_REG_PER_MAC_OFFSET 0x14 
#define RCP_REG_OQ_PER_MAC_OFFSET 0x200
#define RCP_REG_RATE_PER_MAC_OFFSET 0x04

void rcp_rate_calc(int signum);    // timeout every 'T'ms and update RCP rate
double running_avg(double var_sample, double var_last_avg, double gain);
inline double max(double d1, double d2){ if (d1 > d2){return d1;} else {return d2;} }
inline double min(double d1, double d2){ if (d1 < d2){return d1;} else {return d2;} }

/* ------------ Variables ----------------- */

double link_capacity_ = 125000; // in Bytes/msec (1 Gbps)
double input_traffic_ = 0.0; // Bytes
double avg_rtt_ = RTT; // msec
double Tq_ = TIMESLOT; // msec
unsigned int Q_ = 0; // Bytes
unsigned int flow_rate_ = 125000 * INIT_RATE_FACT; // Bytes/msec
double min_pprtt_ = 0.1; // minimum rate in pkts/RTT
struct sigaction sa_; 
struct itimerval timer_; 
FILE* fStats;	// /proc file for kernel stats
FILE* fRate;	//	/proc file for writing RCP rate
char statsFileName[] = "/proc/rcp/stat";
char rateFileName[]	= "/proc/rcp/rate";
unsigned int mac_index = 0;

/* ------------------- Code ----------------- */


int main(int argc, char *argv[]) 
{
	
	  int cpci_id;
	  // Parse the argument to decide which MAC this rcpd is monitoring
  
    if (argc != 2) {
        printf("Usage: %s [RCP MAC Index: 0~3]\n", argv[0]);
        exit (0);
    }
  
    mac_index = atoi(argv[1]); 
    if (mac_index >= 0 && mac_index < RCP_MAC_COUNT) {
        printf("Binding %s process with NetFPGA MAC#%d", argv[0], mac_index);
    } else {
        printf("Invalid MAC Index %d\n", mac_index);
        exit(0);
    } 

	  connectnf2();
    
	  // Make sure the CPCI ID is write the value should be 0x2000003
 	  readReg(&nf2,CPCI_ID_REG, &cpci_id);
 	  printf("\n \n CPCI ID = %x \n\n", cpci_id);
 	  if (cpci_id != 0x2000003){
        printf("CPCI ID is not correct\n");
        exit(1);
    }

    int randInt;
		
#ifdef RCP_KERNEL_PROC_FS		
	  //Open /proc files for read/write
	  fStats = fopen(statsFileName, "r+"); // open stats file for reading and writing
	  if (fStats == NULL) {
	 	    fprintf(stderr, "Can't open file %s!\n", statsFileName);
        exit(1);
    }

	  fRate = fopen(rateFileName, "w"); // open rate file for writing RCP rate
	  if (fRate == NULL) {
        fprintf(stderr, "Can't open file %s!\n", rateFileName);
        exit(1);
    }
#endif 
	
	  // Install the timer handler... 
	  memset (&sa_, 0, sizeof (sa_)); 
	  sa_.sa_handler= &rcp_rate_calc; 
	  sigaction (SIGALRM, &sa_, NULL); 
 
	  // Configure the timer to expire in less than 100 msec... 
	  // Randomize the timer to avoid synchronization among routers
	  srand(time(NULL));
	  randInt = rand() % 100; // a random interger between 0 and 99
	  if (randInt < 1)
		    randInt = 1;
	  
	  timer_.it_value.tv_sec= 0;   // First timeout 
	  timer_.it_value.tv_usec= randInt * 1000; 
	  timer_.it_interval.tv_sec= 0;   // Interval 
	  timer_.it_interval.tv_usec= randInt * 1000; 
  
	  // Start timer... 
	  setitimer (ITIMER_REAL, &timer_, NULL); 
 
	  // Main loop 
	  while (1) 
		    sleep (10); 
			
#ifdef RCP_KERNEL_PROC_FS			
	  fclose(fStats);
	  fclose(fRate);			
#endif 

	  return(0);
}

/* Function to compute RCP's rate */

void rcp_rate_calc(int signum)
{
	double tempRate = 0.0;
	char clip;
	double ratio = 0.0;
	double input_traffic_divider = 0.0;
	double virtual_link_capacity = 0.0; // Bytes/msec.
	unsigned long long rttSumTq = 0.0;
	double TqAvgRTT = 0.0;
	double rtt_moving_gain = 0.0;
	unsigned int numPktsValidRTT = 0;
	unsigned int interface_index = 0;
	int val1, val2;
	unsigned long long val_h;
	unsigned int rcp_reg_offset = 0;
	static int counter= 0; 
	
	printf ("timerHandler: counter= %d\n", counter++); 

  rcp_reg_offset = mac_index * RCP_REG_PER_MAC_OFFSET;
  
	/* ------------ Read stats from the kernel ------------------- */
	// Read sum of round-trip times
    readReg(&nf2, RCP_MAC_0_RTT_L_REG + rcp_reg_offset, &val1);
	  readReg(&nf2, RCP_MAC_0_RTT_H_REG + rcp_reg_offset, &val2);
	  val_h = val2;
	  rttSumTq = (val_h<<32)+val1;
        
	  // Number of RCP packets that arry a valid RTT 
	  readReg(&nf2, RCP_MAC_0_NUM_RCP_REG + rcp_reg_offset, &val1);
	  numPktsValidRTT = val1;

	  // Total number of arriving RCP bytes
	  readReg(&nf2, RCP_MAC_0_NUM_BYTE_L_REG + rcp_reg_offset, &val1);
	  readReg(&nf2, RCP_MAC_0_NUM_BYTE_H_REG + rcp_reg_offset, &val2);
	  val_h = val2;
	  input_traffic_=(val_h<<32)+val1;
	
	  // Queue occupancy
	  readReg(&nf2, OQ_NUM_PKTS_STORED_REG_0 + 
                     RCP_REG_OQ_PER_MAC_OFFSET * mac_index, &val1);
	  Q_ = val1;
	  //fscanf(fStats, "%u\t%lu\t%lu\t%lu\n", &interface_index, &rttSumTq, &numPktsValidRTT, &input_traffic_, &Q_);
	  
	  /* -------------- Compute avg_rtt ----------------------------- */

	  if (numPktsValidRTT > 0)
		    TqAvgRTT = rttSumTq/numPktsValidRTT; 

	  if (TqAvgRTT >= avg_rtt_)
		    rtt_moving_gain = (Tq_/avg_rtt_);
	  else 
        rtt_moving_gain = ((float)flow_rate_/link_capacity_)*(TqAvgRTT/avg_rtt_)*(Tq_/avg_rtt_);

	  avg_rtt_ = running_avg(TqAvgRTT, avg_rtt_, rtt_moving_gain);
  
	  /* -------------- Compute Rate --------------------------------- */
  
	  virtual_link_capacity = GAMMA * link_capacity_;
	  input_traffic_divider = input_traffic_/Tq_; // Bytes/msec
	  ratio		= (1 + ((Tq_/avg_rtt_)*(ALPHA*(virtual_link_capacity - input_traffic_divider) - BETA*(Q_/avg_rtt_)))/virtual_link_capacity);
    tempRate	= flow_rate_ * ratio;

	  if (tempRate < min_pprtt_ * (PKTSIZE/avg_rtt_) ) {  
		    flow_rate_ = min_pprtt_ * (PKTSIZE/avg_rtt_) ; // min-pkts/RTT 
		    clip  = 'L';
    } else if (tempRate > virtual_link_capacity) {
		    flow_rate_ = virtual_link_capacity;
		    clip = 'U';
    } else {
		    flow_rate_ = tempRate;
		    clip = 'M';
    }
	
	  if (flow_rate_ < 1)
		    flow_rate_ = 1; // 1 Byte/ms
		
	  Tq_ = min(avg_rtt_, TIMESLOT); // msec
		
	  /* -------------- Reset Kernel Stats ---------------------------- */
	  // Reset RTT
	  writeReg(&nf2, RCP_MAC_0_RTT_L_REG + rcp_reg_offset, 0);
	  writeReg(&nf2, RCP_MAC_0_RTT_H_REG + rcp_reg_offset, 0);

	  // Reset Number of RCP packets carrying a valid RTT
	  writeReg(&nf2, RCP_MAC_0_NUM_RCP_REG + rcp_reg_offset, 0);

	  // Reset number of incoming RCP bytes
	  writeReg(&nf2, RCP_MAC_0_NUM_BYTE_L_REG + rcp_reg_offset, 0);
	  writeReg(&nf2, RCP_MAC_0_NUM_BYTE_H_REG + rcp_reg_offset, 0);

	  //fprintf(fStats, "%u", interface_index);
	
	  /* -------------- Write RCP Rate ------------------------------- */
	  writeReg(&nf2, 
                   RCP_RATE_0_REG + 
                       mac_index * RCP_REG_RATE_PER_MAC_OFFSET, 
                   flow_rate_);
	  //fprintf(fRate, "%u %lu", interface_index, flow_rate_);
	  printf("flow rate=%lu\n", flow_rate_);
	  /* -------------- Reschedule Timer ------------------------------ */

	  timer_.it_value.tv_sec= 0;   // First timeout 
	  timer_.it_value.tv_usec= Tq_ * 1000; //usec 
	  timer_.it_interval.tv_sec= 0;   // Interval 
	  timer_.it_interval.tv_usec= Tq_ * 1000; //usec 
	  setitimer (ITIMER_REAL, &timer_, NULL);

	  fflush (stdout); 

}

double running_avg(double var_sample, double var_last_avg, double gain)
{
	  double avg;
	  if (gain < 0)
		    return 0;
	  avg = gain * var_sample + ( 1 - gain) * var_last_avg;
	  return avg;
}
