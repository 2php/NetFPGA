/* ****************************************************************************
 * $Id: regdump.c 4284 2008-07-11 23:00:51Z sbolouki $
 *
 * Module: regdump.c
 * Project: NetFPGA 2.1 reference
 * Description: Test program to dump the switch registers
 *
 * Change history:
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>

#include <net/if.h>

#include <time.h>

#include "../lib/C/reg_defines_rcp_router.h"
#include "../../../lib/C/common/reg_defines.h"
#include "../../../lib/C/common/nf2util.h"

#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;
static int force_cnet = 0;

/* Function declarations */
void print (void);
void printMAC (unsigned, unsigned);
void printIP (unsigned);

int main(int argc, char *argv[])
{
	unsigned val;

	nf2.device_name = DEFAULT_IFACE;

	if (check_iface(&nf2))
	{
		exit(1);
	}
	if (openDescriptor(&nf2))
	{
		exit(1);
	}

	print();

	closeDescriptor(&nf2);

	return 0;
}

void print(void) {
	unsigned val, val2;
	int i;

	//	readReg(&nf2, UNET_ID, &val);
	//	printf("Board ID: Version %i, Device %i\n", GET_VERSION(val), GET_DEVICE(val));
	readReg(&nf2, MAC_GRP_0_CONTROL_REG, &val);
	printf("MAC 0 Control: 0x%08x ", val);
	if(val&(1<<TX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("TX disabled, ");
	}
	else {
	  printf("TX enabled,  ");
	}
	if(val&(1<<RX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("RX disabled, ");
	}
	else {
	  printf("RX enabled,  ");
	}
	if(val&(1<<RESET_MAC_BIT_NUM)) {
	  printf("reset on\n");
	}
	else {
	  printf("reset off\n");
	}
	printf("mac config 0x%02x\n", val>>MAC_DISABLE_TX_BIT_NUM);

	readReg(&nf2, RX_QUEUE_0_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts enqueued to rx queue 0:      %u\n", val);
	readReg(&nf2, RX_QUEUE_0_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 0 full): %u\n", val);
	readReg(&nf2, RX_QUEUE_0_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 0):     %u\n", val);
	readReg(&nf2, RX_QUEUE_0_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 0: %u\n", val);
	readReg(&nf2, RX_QUEUE_0_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 0: %u\n", val);
	readReg(&nf2, RX_QUEUE_0_NUM_PKTS_DEQUEUED_REG, &val);
	printf("Num pkts dequeued from rx queue 0: %u\n", val);
	readReg(&nf2, RX_QUEUE_0_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in rx queue 0: %u\n\n", val);

	readReg(&nf2, TX_QUEUE_0_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 0:             %u\n", val);
	readReg(&nf2, TX_QUEUE_0_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts dequeued from tx queue 0:           %u\n", val);
	readReg(&nf2, TX_QUEUE_0_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 0: %u\n", val);
	readReg(&nf2, TX_QUEUE_0_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 0: %u\n", val);
	readReg(&nf2, TX_QUEUE_0_NUM_PKTS_ENQUEUED_REG, &val);
	printf("Num pkts enqueued to tx queue 0: %u\n\n", val);

	readReg(&nf2, MAC_GRP_1_CONTROL_REG, &val);
	printf("MAC 1 Control: 0x%08x ", val);
	if(val&(1<<TX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("TX disabled, ");
	}
	else {
	  printf("TX enabled,  ");
	}
	if(val&(1<<RX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("RX disabled, ");
	}
	else {
	  printf("RX enabled,  ");
	}
	if(val&(1<<RESET_MAC_BIT_NUM)) {
	  printf("reset on\n");
	}
	else {
	  printf("reset off\n");
	}
	printf("mac config 0x%02x\n", val>>MAC_DISABLE_TX_BIT_NUM);
	readReg(&nf2, RX_QUEUE_1_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts enqueued to rx queue 1:      %u\n", val);
	readReg(&nf2, RX_QUEUE_1_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 1 full): %u\n", val);
	readReg(&nf2, RX_QUEUE_1_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 1):     %u\n", val);
	readReg(&nf2, RX_QUEUE_1_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 1: %u\n", val);
	readReg(&nf2, RX_QUEUE_1_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 1: %u\n", val);
	readReg(&nf2, RX_QUEUE_1_NUM_PKTS_DEQUEUED_REG, &val);
	printf("Num pkts dequeued from rx queue 1: %u\n", val);
	readReg(&nf2, RX_QUEUE_1_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in rx queue 1: %u\n\n", val);

	readReg(&nf2, TX_QUEUE_1_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 1:             %u\n", val);
	readReg(&nf2, TX_QUEUE_1_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts dequeued from tx queue 1:           %u\n", val);
	readReg(&nf2, TX_QUEUE_1_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 1: %u\n", val);
	readReg(&nf2, TX_QUEUE_1_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 1: %u\n", val);
        readReg(&nf2, TX_QUEUE_1_NUM_PKTS_ENQUEUED_REG, &val);
        printf("Num pkts enqueued to tx queue 1: %u\n\n", val);

	readReg(&nf2, MAC_GRP_2_CONTROL_REG, &val);
	printf("MAC 2 Control: 0x%08x ", val);
	if(val&(1<<TX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("TX disabled, ");
	}
	else {
	  printf("TX enabled,  ");
	}
	if(val&(1<<RX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("RX disabled, ");
	}
	else {
	  printf("RX enabled,  ");
	}
	if(val&(1<<RESET_MAC_BIT_NUM)) {
	  printf("reset on\n");
	}
	else {
	  printf("reset off\n");
	}
	printf("mac config 0x%02x\n", val>>MAC_DISABLE_TX_BIT_NUM);
	readReg(&nf2, RX_QUEUE_2_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts enqueued to rx queue 2:      %u\n", val);
	readReg(&nf2, RX_QUEUE_2_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 2 full): %u\n", val);
	readReg(&nf2, RX_QUEUE_2_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 2):     %u\n", val);
	readReg(&nf2, RX_QUEUE_2_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 2: %u\n", val);
	readReg(&nf2, RX_QUEUE_2_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 2: %u\n", val);
	readReg(&nf2, RX_QUEUE_2_NUM_PKTS_DEQUEUED_REG, &val);
	printf("Num pkts dequeued from rx queue 2: %u\n", val);
	readReg(&nf2, RX_QUEUE_2_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in rx queue 2: %u\n\n", val);

	readReg(&nf2, TX_QUEUE_2_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 2:             %u\n", val);
	readReg(&nf2, TX_QUEUE_2_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts dequeued from tx queue 2:           %u\n", val);
	readReg(&nf2, TX_QUEUE_2_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 2: %u\n", val);
	readReg(&nf2, TX_QUEUE_2_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 2: %u\n", val);
        readReg(&nf2, TX_QUEUE_2_NUM_PKTS_ENQUEUED_REG, &val);
        printf("Num pkts enqueued to tx queue 2: %u\n\n", val);

	readReg(&nf2, MAC_GRP_3_CONTROL_REG, &val);
	printf("MAC 3 Control: 0x%08x ", val);
	if(val&(1<<TX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("TX disabled, ");
	}
	else {
	  printf("TX enabled,  ");
	}
	if(val&(1<<RX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("RX disabled, ");
	}
	else {
	  printf("RX enabled,  ");
	}
	if(val&(1<<RESET_MAC_BIT_NUM)) {
	  printf("reset on\n");
	}
	else {
	  printf("reset off\n");
	}
        printf("mac config 0x%02x\n", val>>MAC_DISABLE_TX_BIT_NUM);
	readReg(&nf2, RX_QUEUE_3_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts enqueued to rx queue 3:      %u\n", val);
	readReg(&nf2, RX_QUEUE_3_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 3 full): %u\n", val);
	readReg(&nf2, RX_QUEUE_3_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 3):     %u\n", val);
	readReg(&nf2, RX_QUEUE_3_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 3: %u\n", val);
	readReg(&nf2, RX_QUEUE_3_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 3: %u\n", val);
	readReg(&nf2, RX_QUEUE_3_NUM_PKTS_DEQUEUED_REG, &val);
	printf("Num pkts dequeued from rx queue 3: %u\n", val);
	readReg(&nf2, RX_QUEUE_3_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in rx queue 3: %u\n\n", val);

	readReg(&nf2, TX_QUEUE_3_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 3:             %u\n", val);
	readReg(&nf2, TX_QUEUE_3_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts dequeued from tx queue 3:           %u\n", val);
	readReg(&nf2, TX_QUEUE_3_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 3: %u\n", val);
	readReg(&nf2, TX_QUEUE_3_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 3: %u\n", val);
        readReg(&nf2, TX_QUEUE_3_NUM_PKTS_ENQUEUED_REG, &val);
        printf("Num pkts enqueued to tx queue 3: %u\n\n", val);

	readReg(&nf2, CPU_REG_Q_0_WR_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_0_WR_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_0_WR_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_0_WR_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_0_WR_NUM_WORDS_LEFT_REG, &val);
	printf("CPU_REG_Q_0_WR_NUM_WORDS_LEFT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_WR_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_0_WR_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RD_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_0_RD_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_0_RD_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_0_RD_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_0_RD_NUM_WORDS_AVAIL_REG, &val);
	printf("CPU_REG_Q_0_RD_NUM_WORDS_AVAIL_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RD_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_0_RD_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RX_NUM_PKTS_RCVD_REG, &val);
	printf("CPU_REG_Q_0_RX_NUM_PKTS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_TX_NUM_PKTS_SENT_REG, &val);
	printf("CPU_REG_Q_0_TX_NUM_PKTS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RX_NUM_WORDS_RCVD_REG, &val);
	printf("CPU_REG_Q_0_RX_NUM_WORDS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_TX_NUM_WORDS_SENT_REG, &val);
	printf("CPU_REG_Q_0_TX_NUM_WORDS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RX_NUM_BYTES_RCVD_REG, &val);
	printf("CPU_REG_Q_0_RX_NUM_BYTES_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_TX_NUM_BYTES_SENT_REG, &val);
	printf("CPU_REG_Q_0_TX_NUM_BYTES_SENT_REG: %u\n\n", val);

	readReg(&nf2, CPU_REG_Q_1_WR_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_1_WR_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_1_WR_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_1_WR_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_1_WR_NUM_WORDS_LEFT_REG, &val);
	printf("CPU_REG_Q_1_WR_NUM_WORDS_LEFT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_WR_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_1_WR_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RD_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_1_RD_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_1_RD_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_1_RD_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_1_RD_NUM_WORDS_AVAIL_REG, &val);
	printf("CPU_REG_Q_1_RD_NUM_WORDS_AVAIL_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RD_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_1_RD_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RX_NUM_PKTS_RCVD_REG, &val);
	printf("CPU_REG_Q_1_RX_NUM_PKTS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_TX_NUM_PKTS_SENT_REG, &val);
	printf("CPU_REG_Q_1_TX_NUM_PKTS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RX_NUM_WORDS_RCVD_REG, &val);
	printf("CPU_REG_Q_1_RX_NUM_WORDS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_TX_NUM_WORDS_SENT_REG, &val);
	printf("CPU_REG_Q_1_TX_NUM_WORDS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RX_NUM_BYTES_RCVD_REG, &val);
	printf("CPU_REG_Q_1_RX_NUM_BYTES_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_TX_NUM_BYTES_SENT_REG, &val);
	printf("CPU_REG_Q_1_TX_NUM_BYTES_SENT_REG: %u\n\n", val);

	readReg(&nf2, CPU_REG_Q_2_WR_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_2_WR_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_2_WR_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_2_WR_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_2_WR_NUM_WORDS_LEFT_REG, &val);
	printf("CPU_REG_Q_2_WR_NUM_WORDS_LEFT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_WR_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_2_WR_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RD_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_2_RD_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_2_RD_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_2_RD_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_2_RD_NUM_WORDS_AVAIL_REG, &val);
	printf("CPU_REG_Q_2_RD_NUM_WORDS_AVAIL_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RD_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_2_RD_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RX_NUM_PKTS_RCVD_REG, &val);
	printf("CPU_REG_Q_2_RX_NUM_PKTS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_TX_NUM_PKTS_SENT_REG, &val);
	printf("CPU_REG_Q_2_TX_NUM_PKTS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RX_NUM_WORDS_RCVD_REG, &val);
	printf("CPU_REG_Q_2_RX_NUM_WORDS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_TX_NUM_WORDS_SENT_REG, &val);
	printf("CPU_REG_Q_2_TX_NUM_WORDS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RX_NUM_BYTES_RCVD_REG, &val);
	printf("CPU_REG_Q_2_RX_NUM_BYTES_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_TX_NUM_BYTES_SENT_REG, &val);
	printf("CPU_REG_Q_2_TX_NUM_BYTES_SENT_REG: %u\n\n", val);

	readReg(&nf2, CPU_REG_Q_3_WR_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_3_WR_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_3_WR_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_3_WR_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_3_WR_NUM_WORDS_LEFT_REG, &val);
	printf("CPU_REG_Q_3_WR_NUM_WORDS_LEFT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_WR_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_3_WR_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RD_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_3_RD_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_3_RD_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_3_RD_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_3_RD_NUM_WORDS_AVAIL_REG, &val);
	printf("CPU_REG_Q_3_RD_NUM_WORDS_AVAIL_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RD_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_3_RD_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RX_NUM_PKTS_RCVD_REG, &val);
	printf("CPU_REG_Q_3_RX_NUM_PKTS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_TX_NUM_PKTS_SENT_REG, &val);
	printf("CPU_REG_Q_3_TX_NUM_PKTS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RX_NUM_WORDS_RCVD_REG, &val);
	printf("CPU_REG_Q_3_RX_NUM_WORDS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_TX_NUM_WORDS_SENT_REG, &val);
	printf("CPU_REG_Q_3_TX_NUM_WORDS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RX_NUM_BYTES_RCVD_REG, &val);
	printf("CPU_REG_Q_3_RX_NUM_BYTES_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_TX_NUM_BYTES_SENT_REG, &val);
	printf("CPU_REG_Q_3_TX_NUM_BYTES_SENT_REG: %u\n\n", val);

	for(i=0; i<ROUTER_ARP_SIZE; i=i+1){
	  writeReg(&nf2, ROUTER_OP_LUT_ARP_LUT_RD_ADDR_REG, i);
	  printf("   ARP table entry %02u: mac: ", i);
	  readReg(&nf2, ROUTER_OP_LUT_ARP_MAC_HI_REG, &val);
	  readReg(&nf2, ROUTER_OP_LUT_ARP_MAC_LO_REG, &val2);
	  printMAC(val, val2);
	  printf(" ip: ");
	  readReg(&nf2, ROUTER_OP_LUT_ARP_NEXT_HOP_IP_REG, &val);
	  printIP(val);
	  printf("\n", val);
	}
	printf("\n");

	for(i=0; i<ROUTER_RT_SIZE; i=i+1){
	  writeReg(&nf2, ROUTER_OP_LUT_RT_LUT_RD_ADDR_REG, i);
	  readReg(&nf2, ROUTER_OP_LUT_RT_IP_REG, &val);
	  printf("   IP table entry %02u: ip: ", i);
	  printIP(val);
	  readReg(&nf2, ROUTER_OP_LUT_RT_MASK_REG, &val);
	  printf(" mask: 0x%08x", val);
	  readReg(&nf2, ROUTER_OP_LUT_RT_NEXT_HOP_IP_REG, &val);
	  printf(" next hop: ");
	  printIP(val);
	  readReg(&nf2, ROUTER_OP_LUT_RT_OUTPUT_PORT_REG, &val);
	  printf(" output port: 0x%04x\n", val);
	}
	printf("\n");

	for(i=0; i<ROUTER_DST_IP_FILTER_TABLE_DEPTH; i=i+1){
	  writeReg(&nf2, ROUTER_OP_LUT_DST_IP_FILTER_RD_ADDR_REG, i);
	  readReg(&nf2, ROUTER_OP_LUT_DST_IP_FILTER_IP_REG, &val);
	  printf("   Dst IP Filter table entry %02u: ", i);
	  printIP(val);
	  printf("\n");
	}
	printf("\n");

	readReg(&nf2, ROUTER_OP_LUT_ARP_NUM_MISSES_REG, &val);
	printf("ROUTER_OP_LUT_ARP_NUM_MISSES_REG: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_LPM_NUM_MISSES_REG, &val);
	printf("ROUTER_OP_LUT_LPM_NUM_MISSES_REG: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_CPU_PKTS_SENT_REG, &val);
	printf("ROUTER_OP_LUT_NUM_CPU_PKTS_SENT_REG: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_BAD_OPTS_VER_REG, &val);
	printf("ROUTER_OP_LUT_NUM_BAD_OPTS_VER_REG: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_BAD_CHKSUMS_REG, &val);
	printf("ROUTER_OP_LUT_NUM_BAD_CHKSUMS_REG: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_BAD_TTLS_REG, &val);
	printf("ROUTER_OP_LUT_NUM_BAD_TTLS_REG: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_NON_IP_RCVD_REG, &val);
	printf("ROUTER_OP_LUT_NUM_NON_IP_RCVD_REG: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG, &val);
	printf("ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_WRONG_DEST_REG, &val);
	printf("ROUTER_OP_LUT_NUM_WRONG_DEST_REG: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG, &val);
	printf("ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG: %u\n", val);
	printf("\n");

	readReg(&nf2, ROUTER_OP_LUT_MAC_0_HI_REG, &val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_0_LO_REG, &val2);
	printf("ROUTER_OP_LUT_MAC_0: ");
	printMAC(val, val2);
	printf("\n");
	readReg(&nf2, ROUTER_OP_LUT_MAC_1_HI_REG, &val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_1_LO_REG, &val2);
	printf("ROUTER_OP_LUT_MAC_1: ");
	printMAC(val, val2);
	printf("\n");
	readReg(&nf2, ROUTER_OP_LUT_MAC_2_HI_REG, &val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_2_LO_REG, &val2);
	printf("ROUTER_OP_LUT_MAC_2: ");
	printMAC(val, val2);
	printf("\n");
	readReg(&nf2, ROUTER_OP_LUT_MAC_3_HI_REG, &val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_3_LO_REG, &val2);
	printf("ROUTER_OP_LUT_MAC_3: ");
	printMAC(val, val2);
	printf("\n");

	/*
	readReg(&nf2, ROUTER_OP_LUT_MAC_0_HI_REG, &val);
	printf("ROUTER_OP_LUT_MAC_0_HI_REG: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_0_LO_REG, &val);
	printf("ROUTER_OP_LUT_MAC_0_LO_REG: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_1_HI_REG, &val);
	printf("ROUTER_OP_LUT_MAC_1_HI_REG: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_1_LO_REG, &val);
	printf("ROUTER_OP_LUT_MAC_1_LO_REG: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_2_HI_REG, &val);
	printf("ROUTER_OP_LUT_MAC_2_HI_REG: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_2_LO_REG, &val);
	printf("ROUTER_OP_LUT_MAC_2_LO_REG: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_3_HI_REG, &val);
	printf("ROUTER_OP_LUT_MAC_3_HI_REG: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_3_LO_REG, &val);
	printf("ROUTER_OP_LUT_MAC_3_LO_REG: 0x%08x\n\n", val);
	*/

	readReg(&nf2, IN_ARB_NUM_PKTS_SENT_REG, &val);
	printf("IN_ARB_NUM_PKTS_SENT_REG                  %u\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_0_LO_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_0_LO_REG             0x%08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_0_HI_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_0_HI_REG             0x%08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_CTRL_0_REG, &val);
	printf("IN_ARB_LAST_PKT_CTRL_0_REG                0x%02x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_1_LO_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_1_LO_REG             0x%08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_1_HI_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_1_HI_REG             0x%08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_CTRL_1_REG, &val);
	printf("IN_ARB_LAST_PKT_CTRL_1_REG                0x%02x\n", val);
	readReg(&nf2, IN_ARB_STATE_REG, &val);
	printf("IN_ARB_STATE_REG                          %u\n\n", val);

	readReg(&nf2, OQ_NUM_WORDS_LEFT_REG_0, &val);
	printf("OQ_NUM_WORDS_LEFT_REG_0                   %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_STORED_REG_0, &val);
	printf("OQ_NUM_PKT_BYTES_STORED_REG_0             %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_STORED_REG_0, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_STORED_REG_0        %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_STORED_REG_0, &val);
	printf("OQ_NUM_PKTS_STORED_REG_0                  %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_DROPPED_REG_0, &val);
	printf("OQ_NUM_PKTS_DROPPED_REG_0                 %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_REMOVED_REG_0, &val);
	printf("OQ_NUM_PKT_BYTES_REMOVED_REG_0            %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_0, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_0       %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_REMOVED_REG_0, &val);
	printf("OQ_NUM_PKTS_REMOVED_REG_0                 %u\n", val);
	readReg(&nf2, OQ_ADDRESS_LO_REG_0, &val);
	printf("OQ_ADDRESS_LO_REG_0                       0x%08x\n", val);
	readReg(&nf2, OQ_ADDRESS_HI_REG_0, &val);
	printf("OQ_ADDRESS_HI_REG_0                       0x%08x\n", val);
	readReg(&nf2, OQ_WR_ADDRESS_REG_0, &val);
	printf("OQ_WR_ADDRESS_REG_0                       0x%08x\n", val);
	readReg(&nf2, OQ_RD_ADDRESS_REG_0, &val);
	printf("OQ_RD_ADDRESS_REG_0                       0x%08x\n", val);
	readReg(&nf2, OQ_NUM_PKTS_IN_Q_REG_0, &val);
	printf("OQ_NUM_PKTS_IN_Q_REG_0                    %u\n", val);
	readReg(&nf2, OQ_MAX_PKTS_IN_Q_REG_0, &val);
	printf("OQ_MAX_PKTS_IN_Q_REG_0                    %u\n", val);
	readReg(&nf2, OQ_CONTROL_REG_0, &val);
	printf("OQ_CONTROL_REG_0                          0x%08x\n\n", val);

	readReg(&nf2, OQ_NUM_WORDS_LEFT_REG_1, &val);
	printf("OQ_NUM_WORDS_LEFT_REG_1                   %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_STORED_REG_1, &val);
	printf("OQ_NUM_PKT_BYTES_STORED_REG_1             %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_STORED_REG_1, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_STORED_REG_1        %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_STORED_REG_1, &val);
	printf("OQ_NUM_PKTS_STORED_REG_1                  %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_DROPPED_REG_1, &val);
	printf("OQ_NUM_PKTS_DROPPED_REG_1                 %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_REMOVED_REG_1, &val);
	printf("OQ_NUM_PKT_BYTES_REMOVED_REG_1            %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_1, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_1       %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_REMOVED_REG_1, &val);
	printf("OQ_NUM_PKTS_REMOVED_REG_1                 %u\n", val);
	readReg(&nf2, OQ_ADDRESS_LO_REG_1, &val);
	printf("OQ_ADDRESS_LO_REG_1                       0x%08x\n", val);
	readReg(&nf2, OQ_ADDRESS_HI_REG_1, &val);
	printf("OQ_ADDRESS_HI_REG_1                       0x%08x\n", val);
	readReg(&nf2, OQ_WR_ADDRESS_REG_1, &val);
	printf("OQ_WR_ADDRESS_REG_1                       0x%08x\n", val);
	readReg(&nf2, OQ_RD_ADDRESS_REG_1, &val);
	printf("OQ_RD_ADDRESS_REG_1                       0x%08x\n", val);
	readReg(&nf2, OQ_NUM_PKTS_IN_Q_REG_1, &val);
	printf("OQ_NUM_PKTS_IN_Q_REG_1                    %u\n", val);
	readReg(&nf2, OQ_MAX_PKTS_IN_Q_REG_1, &val);
	printf("OQ_MAX_PKTS_IN_Q_REG_1                    %u\n", val);
	readReg(&nf2, OQ_CONTROL_REG_1, &val);
	printf("OQ_CONTROL_REG_1                          0x%08x\n\n", val);

	readReg(&nf2, OQ_NUM_WORDS_LEFT_REG_2, &val);
	printf("OQ_NUM_WORDS_LEFT_REG_2                   %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_STORED_REG_2, &val);
	printf("OQ_NUM_PKT_BYTES_STORED_REG_2             %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_STORED_REG_2, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_STORED_REG_2        %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_STORED_REG_2, &val);
	printf("OQ_NUM_PKTS_STORED_REG_2                  %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_DROPPED_REG_2, &val);
	printf("OQ_NUM_PKTS_DROPPED_REG_2                 %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_REMOVED_REG_2, &val);
	printf("OQ_NUM_PKT_BYTES_REMOVED_REG_2            %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_2, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_2       %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_REMOVED_REG_2, &val);
	printf("OQ_NUM_PKTS_REMOVED_REG_2                 %u\n", val);
	readReg(&nf2, OQ_ADDRESS_LO_REG_2, &val);
	printf("OQ_ADDRESS_LO_REG_2                       0x%08x\n", val);
	readReg(&nf2, OQ_ADDRESS_HI_REG_2, &val);
	printf("OQ_ADDRESS_HI_REG_2                       0x%08x\n", val);
	readReg(&nf2, OQ_WR_ADDRESS_REG_2, &val);
	printf("OQ_WR_ADDRESS_REG_2                       0x%08x\n", val);
	readReg(&nf2, OQ_RD_ADDRESS_REG_2, &val);
	printf("OQ_RD_ADDRESS_REG_2                       0x%08x\n", val);
	readReg(&nf2, OQ_NUM_PKTS_IN_Q_REG_2, &val);
	printf("OQ_NUM_PKTS_IN_Q_REG_2                    %u\n", val);
	readReg(&nf2, OQ_MAX_PKTS_IN_Q_REG_2, &val);
	printf("OQ_MAX_PKTS_IN_Q_REG_2                    %u\n", val);
	readReg(&nf2, OQ_CONTROL_REG_2, &val);
	printf("OQ_CONTROL_REG_2                          0x%08x\n\n", val);

	readReg(&nf2, OQ_NUM_WORDS_LEFT_REG_3, &val);
	printf("OQ_NUM_WORDS_LEFT_REG_3                   %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_STORED_REG_3, &val);
	printf("OQ_NUM_PKT_BYTES_STORED_REG_3             %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_STORED_REG_3, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_STORED_REG_3        %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_STORED_REG_3, &val);
	printf("OQ_NUM_PKTS_STORED_REG_3                  %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_DROPPED_REG_3, &val);
	printf("OQ_NUM_PKTS_DROPPED_REG_3                 %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_REMOVED_REG_3, &val);
	printf("OQ_NUM_PKT_BYTES_REMOVED_REG_3            %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_3, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_3       %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_REMOVED_REG_3, &val);
	printf("OQ_NUM_PKTS_REMOVED_REG_3                 %u\n", val);
	readReg(&nf2, OQ_ADDRESS_LO_REG_3, &val);
	printf("OQ_ADDRESS_LO_REG_3                       0x%08x\n", val);
	readReg(&nf2, OQ_ADDRESS_HI_REG_3, &val);
	printf("OQ_ADDRESS_HI_REG_3                       0x%08x\n", val);
	readReg(&nf2, OQ_WR_ADDRESS_REG_3, &val);
	printf("OQ_WR_ADDRESS_REG_3                       0x%08x\n", val);
	readReg(&nf2, OQ_RD_ADDRESS_REG_3, &val);
	printf("OQ_RD_ADDRESS_REG_3                       0x%08x\n", val);
	readReg(&nf2, OQ_NUM_PKTS_IN_Q_REG_3, &val);
	printf("OQ_NUM_PKTS_IN_Q_REG_3                    %u\n", val);
	readReg(&nf2, OQ_MAX_PKTS_IN_Q_REG_3, &val);
	printf("OQ_MAX_PKTS_IN_Q_REG_3                    %u\n", val);
	readReg(&nf2, OQ_CONTROL_REG_3, &val);
	printf("OQ_CONTROL_REG_3                          0x%08x\n\n", val);

	readReg(&nf2, OQ_NUM_WORDS_LEFT_REG_4, &val);
	printf("OQ_NUM_WORDS_LEFT_REG_4                   %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_STORED_REG_4, &val);
	printf("OQ_NUM_PKT_BYTES_STORED_REG_4             %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_STORED_REG_4, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_STORED_REG_4        %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_STORED_REG_4, &val);
	printf("OQ_NUM_PKTS_STORED_REG_4                  %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_DROPPED_REG_4, &val);
	printf("OQ_NUM_PKTS_DROPPED_REG_4                 %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_REMOVED_REG_4, &val);
	printf("OQ_NUM_PKT_BYTES_REMOVED_REG_4            %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_4, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_4       %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_REMOVED_REG_4, &val);
	printf("OQ_NUM_PKTS_REMOVED_REG_4                 %u\n", val);
	readReg(&nf2, OQ_ADDRESS_LO_REG_4, &val);
	printf("OQ_ADDRESS_LO_REG_4                       0x%08x\n", val);
	readReg(&nf2, OQ_ADDRESS_HI_REG_4, &val);
	printf("OQ_ADDRESS_HI_REG_4                       0x%08x\n", val);
	readReg(&nf2, OQ_WR_ADDRESS_REG_4, &val);
	printf("OQ_WR_ADDRESS_REG_4                       0x%08x\n", val);
	readReg(&nf2, OQ_RD_ADDRESS_REG_4, &val);
	printf("OQ_RD_ADDRESS_REG_4                       0x%08x\n", val);
	readReg(&nf2, OQ_NUM_PKTS_IN_Q_REG_4, &val);
	printf("OQ_NUM_PKTS_IN_Q_REG_4                    %u\n", val);
	readReg(&nf2, OQ_MAX_PKTS_IN_Q_REG_4, &val);
	printf("OQ_MAX_PKTS_IN_Q_REG_4                    %u\n", val);
	readReg(&nf2, OQ_CONTROL_REG_4, &val);
	printf("OQ_CONTROL_REG_4                          0x%08x\n\n", val);

	readReg(&nf2, OQ_NUM_WORDS_LEFT_REG_5, &val);
	printf("OQ_NUM_WORDS_LEFT_REG_5                   %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_STORED_REG_5, &val);
	printf("OQ_NUM_PKT_BYTES_STORED_REG_5             %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_STORED_REG_5, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_STORED_REG_5        %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_STORED_REG_5, &val);
	printf("OQ_NUM_PKTS_STORED_REG_5                  %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_DROPPED_REG_5, &val);
	printf("OQ_NUM_PKTS_DROPPED_REG_5                 %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_REMOVED_REG_5, &val);
	printf("OQ_NUM_PKT_BYTES_REMOVED_REG_5            %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_5, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_5       %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_REMOVED_REG_5, &val);
	printf("OQ_NUM_PKTS_REMOVED_REG_5                 %u\n", val);
	readReg(&nf2, OQ_ADDRESS_LO_REG_5, &val);
	printf("OQ_ADDRESS_LO_REG_5                       0x%08x\n", val);
	readReg(&nf2, OQ_ADDRESS_HI_REG_5, &val);
	printf("OQ_ADDRESS_HI_REG_5                       0x%08x\n", val);
	readReg(&nf2, OQ_WR_ADDRESS_REG_5, &val);
	printf("OQ_WR_ADDRESS_REG_5                       0x%08x\n", val);
	readReg(&nf2, OQ_RD_ADDRESS_REG_5, &val);
	printf("OQ_RD_ADDRESS_REG_5                       0x%08x\n", val);
	readReg(&nf2, OQ_NUM_PKTS_IN_Q_REG_5, &val);
	printf("OQ_NUM_PKTS_IN_Q_REG_5                    %u\n", val);
	readReg(&nf2, OQ_MAX_PKTS_IN_Q_REG_5, &val);
	printf("OQ_MAX_PKTS_IN_Q_REG_5                    %u\n", val);
	readReg(&nf2, OQ_CONTROL_REG_5, &val);
	printf("OQ_CONTROL_REG_5                          0x%08x\n\n", val);

	readReg(&nf2, OQ_NUM_WORDS_LEFT_REG_6, &val);
	printf("OQ_NUM_WORDS_LEFT_REG_6                   %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_STORED_REG_6, &val);
	printf("OQ_NUM_PKT_BYTES_STORED_REG_6             %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_STORED_REG_6, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_STORED_REG_6        %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_STORED_REG_6, &val);
	printf("OQ_NUM_PKTS_STORED_REG_6                  %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_DROPPED_REG_6, &val);
	printf("OQ_NUM_PKTS_DROPPED_REG_6                 %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_REMOVED_REG_6, &val);
	printf("OQ_NUM_PKT_BYTES_REMOVED_REG_6            %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_6, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_6       %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_REMOVED_REG_6, &val);
	printf("OQ_NUM_PKTS_REMOVED_REG_6                 %u\n", val);
	readReg(&nf2, OQ_ADDRESS_LO_REG_6, &val);
	printf("OQ_ADDRESS_LO_REG_6                       0x%08x\n", val);
	readReg(&nf2, OQ_ADDRESS_HI_REG_6, &val);
	printf("OQ_ADDRESS_HI_REG_6                       0x%08x\n", val);
	readReg(&nf2, OQ_WR_ADDRESS_REG_6, &val);
	printf("OQ_WR_ADDRESS_REG_6                       0x%08x\n", val);
	readReg(&nf2, OQ_RD_ADDRESS_REG_6, &val);
	printf("OQ_RD_ADDRESS_REG_6                       0x%08x\n", val);
	readReg(&nf2, OQ_NUM_PKTS_IN_Q_REG_6, &val);
	printf("OQ_NUM_PKTS_IN_Q_REG_6                    %u\n", val);
	readReg(&nf2, OQ_MAX_PKTS_IN_Q_REG_6, &val);
	printf("OQ_MAX_PKTS_IN_Q_REG_6                    %u\n", val);
	readReg(&nf2, OQ_CONTROL_REG_6, &val);
	printf("OQ_CONTROL_REG_6                          0x%08x\n\n", val);

	readReg(&nf2, OQ_NUM_WORDS_LEFT_REG_7, &val);
	printf("OQ_NUM_WORDS_LEFT_REG_7                   %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_STORED_REG_7, &val);
	printf("OQ_NUM_PKT_BYTES_STORED_REG_7             %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_STORED_REG_7, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_STORED_REG_7        %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_STORED_REG_7, &val);
	printf("OQ_NUM_PKTS_STORED_REG_7                  %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_DROPPED_REG_7, &val);
	printf("OQ_NUM_PKTS_DROPPED_REG_7                 %u\n", val);
	readReg(&nf2, OQ_NUM_PKT_BYTES_REMOVED_REG_7, &val);
	printf("OQ_NUM_PKT_BYTES_REMOVED_REG_7            %u\n", val);
	readReg(&nf2, OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_7, &val);
	printf("OQ_NUM_OVERHEAD_BYTES_REMOVED_REG_7       %u\n", val);
	readReg(&nf2, OQ_NUM_PKTS_REMOVED_REG_7, &val);
	printf("OQ_NUM_PKTS_REMOVED_REG_7                 %u\n", val);
	readReg(&nf2, OQ_ADDRESS_LO_REG_7, &val);
	printf("OQ_ADDRESS_LO_REG_7                       0x%08x\n", val);
	readReg(&nf2, OQ_ADDRESS_HI_REG_7, &val);
	printf("OQ_ADDRESS_HI_REG_7                       0x%08x\n", val);
	readReg(&nf2, OQ_WR_ADDRESS_REG_7, &val);
	printf("OQ_WR_ADDRESS_REG_7                       0x%08x\n", val);
	readReg(&nf2, OQ_RD_ADDRESS_REG_7, &val);
	printf("OQ_RD_ADDRESS_REG_7                       0x%08x\n", val);
	readReg(&nf2, OQ_NUM_PKTS_IN_Q_REG_7, &val);
	printf("OQ_NUM_PKTS_IN_Q_REG_7                    %u\n", val);
	readReg(&nf2, OQ_MAX_PKTS_IN_Q_REG_7, &val);
	printf("OQ_MAX_PKTS_IN_Q_REG_7                    %u\n", val);
	readReg(&nf2, OQ_CONTROL_REG_7, &val);
	printf("OQ_CONTROL_REG_7                          0x%08x\n\n", val);

	readReg(&nf2, OQ_FULL_THRESH_REG_0, &val);
	printf("OQ_FULL_THRESH_REG_0                      %u\n",val);
	readReg(&nf2, OQ_FULL_THRESH_REG_1, &val);
	printf("OQ_FULL_THRESH_REG_1                      %u\n",val);
	readReg(&nf2, OQ_FULL_THRESH_REG_2, &val);
	printf("OQ_FULL_THRESH_REG_2                      %u\n",val);
	readReg(&nf2, OQ_FULL_THRESH_REG_3, &val);
	printf("OQ_FULL_THRESH_REG_3                      %u\n",val);
	readReg(&nf2, OQ_FULL_THRESH_REG_4, &val);
	printf("OQ_FULL_THRESH_REG_4                      %u\n",val);
	readReg(&nf2, OQ_FULL_THRESH_REG_5, &val);
	printf("OQ_FULL_THRESH_REG_5                      %u\n",val);
	readReg(&nf2, OQ_FULL_THRESH_REG_6, &val);
	printf("OQ_FULL_THRESH_REG_6                      %u\n",val);
	readReg(&nf2, OQ_FULL_THRESH_REG_7, &val);
	printf("OQ_FULL_THRESH_REG_7                      %u\n\n",val);

	readReg(&nf2, DELAY_ENABLE_REG, &val);
	printf("DELAY_ENABLE_REG                          0x%08x\n",val);
	readReg(&nf2, DELAY_1ST_WORD_HI_REG, &val);
	printf("DELAY_1ST_WORD_HI_REG                     0x%08x\n",val);
	readReg(&nf2, DELAY_1ST_WORD_LO_REG, &val);
	printf("DELAY_1ST_WORD_LO_REG                     0x%08x\n",val);
	readReg(&nf2, DELAY_LENGTH_REG, &val);
	printf("DELAY_LENGTH_REG                          0x%08x\n\n",val);

	readReg(&nf2, RATE_LIMIT_ENABLE_REG, &val);
	printf("RATE_LIMIT_ENABLE_REG                     0x%08x\n",val);
	readReg(&nf2, RATE_LIMIT_SHIFT_REG, &val);
	printf("RATE_LIMIT_SHIFT_REG                      0x%08x\n\n",val);

	readReg(&nf2, RCP_RATE_1_REG, &val);
	printf("RCP_RATE_1_REG                              %u\n",val);
        readReg(&nf2, RCP_RATE_2_REG, &val);
        printf("RCP_RATE_2_REG                              %u\n",val);

        readReg(&nf2, RCP_RATE_3_REG, &val);
        printf("RCP_RATE_3_REG                              %u\n",val);
        readReg(&nf2, RCP_RATE_4_REG, &val);
        printf("RCP_RATE_4_REG                              %u\n",val);

	readReg(&nf2, RCP_MAC_0_RTT_L_REG, &val);  
	printf("RCP_MAC_0_RTT_L_REG                       0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_0_RTT_H_REG, &val); 
	printf("RCP_MAC_0_RTT_H_REG                       0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_0_NUM_RCP_REG, &val);
	printf("RCP_MAC_0_NUM_RCP_REG                     0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_0_NUM_BYTE_L_REG, &val);
	printf("RCP_MAC_0_NUM_BYTE_L_REG                  0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_0_NUM_BYTE_H_REG, &val);
	printf("RCP_MAC_0_NUM_BYTE_H_REG                  0x%08x\n",val);

	readReg(&nf2, RCP_MAC_1_RTT_L_REG, &val);  
	printf("RCP_MAC_1_RTT_L_REG                       0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_1_RTT_H_REG, &val); 
	printf("RCP_MAC_1_RTT_H_REG                       0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_1_NUM_RCP_REG, &val);
	printf("RCP_MAC_1_NUM_RCP_REG                     0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_1_NUM_BYTE_L_REG, &val);
	printf("RCP_MAC_1_NUM_BYTE_L_REG                  0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_1_NUM_BYTE_H_REG, &val);
	printf("RCP_MAC_1_NUM_BYTE_H_REG                  0x%08x\n",val);

	readReg(&nf2, RCP_MAC_2_RTT_L_REG, &val);  
	printf("RCP_MAC_2_RTT_L_REG                       0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_2_RTT_H_REG, &val); 
	printf("RCP_MAC_2_RTT_H_REG                       0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_2_NUM_RCP_REG, &val);
	printf("RCP_MAC_2_NUM_RCP_REG                     0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_2_NUM_BYTE_L_REG, &val);
	printf("RCP_MAC_2_NUM_BYTE_L_REG                  0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_2_NUM_BYTE_H_REG, &val);
	printf("RCP_MAC_2_NUM_BYTE_H_REG                  0x%08x\n",val);

	readReg(&nf2, RCP_MAC_3_RTT_L_REG, &val);  
	printf("RCP_MAC_3_RTT_L_REG                       0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_3_RTT_H_REG, &val); 
	printf("RCP_MAC_3_RTT_H_REG                       0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_3_NUM_RCP_REG, &val);
	printf("RCP_MAC_3_NUM_RCP_REG                     0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_3_NUM_BYTE_L_REG, &val);
	printf("RCP_MAC_3_NUM_BYTE_L_REG                  0x%08x\n",val);
	readReg(&nf2,  RCP_MAC_3_NUM_BYTE_H_REG, &val);
	printf("RCP_MAC_3_NUM_BYTE_H_REG                  0x%08x\n",val);





}

//
// printMAC: print a MAC address as a : separated value. eg:
//    00:11:22:33:44:55
//
void printMAC(unsigned hi, unsigned lo)
{
	printf("%02x:%02x:%02x:%02x:%02x:%02x", 
			((hi>>8)&0xff), ((hi>>0)&0xff),
			((lo>>24)&0xff), ((lo>>16)&0xff), ((lo>>8)&0xff), ((lo>>0)&0xff)
		);
}


//
// printIP: print an IP address in dotted notation. eg: 192.168.0.1
//
void printIP(unsigned ip)
{
	printf("%u.%u.%u.%u", 
			((ip>>24)&0xff), ((ip>>16)&0xff), ((ip>>8)&0xff), ((ip>>0)&0xff)
		);
}
