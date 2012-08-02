

20 October, 2008.

This is a release of RCP on the NetFPGA system. The release has three parts:

I. The data path of RCP implemented on NetFPGA

The RCP functionality is split between the hardware data path and the software control path. The per-packet data-path processing in hardware are summarized below:

 1) Identifying whether an incoming packet is an RCP packet
 2) Updating a running RTT sum of the outgoing interface, if the packet carries a valid RTT
 3) Updating the aggregate traffic destined to the outgoing interface
 4) Stamping the RCP rate in the outgoing packet

RCP's data-path is described in greater detail in [1].

II. RCP's control path in a user-level program

The control path performs periodic rate and RTT computations, and since these are performed infrequently they are implemented in software. In our implementation this software runs on the host in which the NetFPGA board is installed.

The control path only performs work at initialization when each port of the RCP router is brought online, and at the expiration of each timeslot. Upon expiration of a timer the control path reads the hardware registers to retrieve the RCP statistics, performs the necessary rate and RTT computations, writes the updated RCP rate to the hardware registers, resets the statistics in the hardware registers, and then restarts the timeslot timer.

The following are calculated approximately once per average RTT of traffic transiting the router:

  1) The bandwidth, R(t), allocated to the average data flow.
  2) The moving round-trip time average

The exact computations involved in the control path are articulated in [2]. 

III. RCP end-host in the Linux kernel

RCP at the end-hosts is implemented as its own protocol layer between IP and transport layers.  There are two parts: the RCP layer between transport and IP layer, which carries congestion information from network to the end-system, and the congestion control component in transport layer which adapts the flow-rate based on network feedback. [1] describes an RCP end-host implementation in greater detail.

***********************************************************************************************************************

Installing the RCP router:
Please refer to notes from http://netfpga.org/netfpgawiki/index.php/Guide#Install_Software_1.2 for more details on NetFPGA related installation and configuration intructions. 

RCP Router Sanity Tests:

There are two tests:
  1. In this test packets with higher rates than the line-rate were sent out to MAC 1 on netfpga, while the user-program was running. We expected to see packets with rate set by the user-program at the output. To run this test, first run the user-program with the following command:
	sudo ./sr_router 1
then go to the regress folder of the netfpga directory and run test_rcp_simple test by doing 
	sudo ./run.pl
The outgoing expected packets should carry the rate sets by sr_router (user-program)

  2. The second test injects RCP packets at less than the line rate. The user-program will converge to 95\% of the line-rate (118750 Bytes/msec), and the outgoing RCP packets will carry this rate. To perform this test, change test_rcp_simple to send hundreds of packets with rates smaller than line-rate, and start the RCP user program:
	sudo ./sr_router 1 > rcp_mac1.log
Run grep for the flow rate in the log:
	tail -f rcp_mac1.log | grep "flow rate="
The output should be like this:
flow rate=118750

***********************************************************************************************************************

RCP End-host:

Notes: Assuming Debian or Ubuntu Linux

1. Fetch the kernel source for your linux distribution

sudo apt-get install linux-source
mkdir ~/src
cd ~/src
tar xjvf /usr/src/linux-source-<version-number-here>.tar.bz2
cd linux-source-<version-number-here>

2. Copy over the kernel config file

cp -vi /boot/config-`uname -r` .config

3. patch the rcp host kernel patch and resolve any possible conflicts
cd ~/src 
cd linux-source-<your version number>
<Put the end-host patch in here> 

patch < linux-2.6.16-rcp-host.diff -p1  

4. rebuild the kernel

make menuconfig 
make-kpkg clean # only needed if you want to do a "clean" build
fakeroot make-kpkg --initrd --append-to-version=-mobond kernel-image kernel-headers 

5. Install the new kernel

Just use ipkg to install the new kernel image and kernel headers

cd ..
sudo dpkg -i linux-image-<your kernel version>-xxxxx_i386.deb
sudo dpkg -i linux-headers-<your kernel version>-xxxxx_i386.deb

6. reboot

***********************************************************************************************************************

Notes on Setup and Experiments:

To try out the RCP implementation, you will need to have at least 3 machines, a sender (PC1), a router (R) and a receiver (PC2). The RCP host implementation is used for sending and receiving RCP traffic. The RCP NetFPGA router implementation needs a NetFPGA card installed and configured on the router machine R. 

The end hosts and router can set up as the following topology with the address assignments:

  PC1 [eth0] <--------> [NetFGPA port 0] Router [NetFPGA port1] <------> [eth0] PC2

 PC1:
     eth0: 10.0.1.100/24 

 Router: 
     NetFPGA port #0: 10.0.1.1/24 
     NetFPGA port #1: 10.0.2.1/24  

 PC2:
     eth0: 10.0.2.100/24

You can specify a static route on PC1/PC2 to the rest of the network. 

Sanity Test #1: A single flow

    On PC1, you can use the following script to inject RCP traffic to the network using iperf. 

     iperf -c 10.0.2.100 -t 100 -p 5001 -i 1 > sanity_test_1.PC1.log

    On PC2, you can use the following command line to serve as a traffic sink

     iperf -s -p 5001 -i 1 > sanity_test_1.pc2.log

    On router, start the RCP daemon:

     sr_router 0 > sanity_test_1_mac0.log
     sr_router 1 > sanity_test_1_mac1.log 

    You can monitor the output of iperf utilities on PC1 and PC2 and the logs of rcpd on router. 

Sanity Test #2: Multiple flows with different starting times

    Keep the configuration on router as sanity test #1.

    On PC2, run the following script to start the iperf sink 

     #!/bin/bash
     for i in 1 2 3 4 5
     do
         port=`expr $i + 5000`
         iperf -s -i 1 -p $port > sanity_test_2_pc2_$i.log &
     done

    On PC1, run the following script to inject TCP flow in different time points. 
the 
     #!/bin/bash
     for i in 1 2 3 4 5
         do
         port=`expr $i + 5000`
         length=`expr 100 - $i \* 10` 
         iperf -c 10.0.2.100 -i 1 -p $port -t $length > sanity_test_2_pc1_$i.log &
         sleep 10 
     done

    This script will generate 5 RCP flows from the sender to receiver. Each flow starts 10 seconds apart, and also ramp down 10s apart. 
    This creates 5 flows to ramp up and then ramp down the load on the router. 


***********************************************************************************************************************

[1] "Building a RCP (Rate Control Protocol) Test Network"
    Nandita Dukkipati, Glen Gibb, Nick McKeown and Jiang Zhu
    Hot Interconnects, Stanford, August 2007

[2] Implementing RCP in the IPv6 Hop-by-Hop Options Header
    Internet Draft, September 2006
