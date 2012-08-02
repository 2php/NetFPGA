#!/usr/local/bin/perl -w
# make_pkts.pl
#
#

use NF2::PacketGen;
use NF2::PacketLib;
use SimLib;
use RouterLib;

use reg_defines_drr_router;

$delay = 10000;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );


# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);


# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

####################################################################
# Setup MAC addresses
# 
my $port0 = 0xaabbcc00;
my $f_port0 = '00:00:aa:bb:cc:00';
my $port1 = 0xaabbcc01;
my $f_port1 = '00:00:aa:bb:cc:01';
my $port2 = 0xaabbcc02;
my $f_port2 = '00:00:aa:bb:cc:02';
my $port3 = 0xaabbcc03;
my $f_port3 = '00:00:aa:bb:cc:03';
my $mac0 = 0xcafe0000;
my $f_mac0 = '00:00:ca:fe:00:00';
my $mac1 = 0xcafe0001;
my $f_mac1 = '00:00:ca:fe:00:01';
my $dstip0 = 0x00050607;
my $f_dstip0 = '00.05.06.07';
my $dstip1 = 0x00060609;
my $f_dstip1 = '00.06.06.09';
my $nextip0 = 0x33050607;
my $f_nextip0 = '33.05.06.07';
my $nextip1 = 0x33060609;
my $f_nextip1 = '33.06.06.09';
my $mask0 = 0xFFFFFF00;
my $mask1 = 0xFFFFFF00;
my $nextport0 = 0x00000001;
my $f_nextport0 = 1;
my $nextport1 = 0x00000001;
my $f_nextport1 = 1;
my $ipfilter0 = 0x10111213;
my $f_ipfilter0 = '10.11.12.13';
my $f_randomip0 = '98.76.54.32';
my $f_randommac0 = '12:34:56:78:90:00';

my $start_time = 500;
# setting port MAC addresses
nf_PCI_write32($start_time,$batch, ROUTER_OP_LUT_MAC_0_HI_REG(),0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_MAC_0_LO_REG(),$port0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_MAC_1_HI_REG(),0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_MAC_1_LO_REG(),$port1);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_MAC_2_HI_REG(),0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_MAC_2_LO_REG(),$port2);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_MAC_3_HI_REG(),0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_MAC_3_LO_REG(),$port3);

# ip filter entries
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG(),$ipfilter0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR_REG(),2);

#routing table entries
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(),$dstip0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(),$mask0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(),$nextip0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG(),$nextport0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG(),0);

nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(),$dstip1);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(),$mask1);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(),$nextip1);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG(),$nextport1);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG(),1);

#arp table entries
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(),0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(),$mac0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(),$nextip0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG(),0);

nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(),0);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(),$mac1);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(),$nextip1);
nf_PCI_write32(0,$batch, ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG(),1);

#DRR regs initialize
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE0_NUM_DROP_REG(),0);
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE1_NUM_DROP_REG(),0);
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE2_NUM_DROP_REG(),0);
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE3_NUM_DROP_REG(),0);
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE4_NUM_DROP_REG(),0);
nf_PCI_write32(0,$batch, DRR_OQ_SLOW_FACTOR_REG(),8);
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE0_CREDIT_REG(),250);
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE1_CREDIT_REG(),90);
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE2_CREDIT_REG(),90);
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE3_CREDIT_REG(),150);
nf_PCI_write32(0,$batch, DRR_OQ_QUEUE4_CREDIT_REG(),150);
nf_PCI_write32(0,$batch, DRR_QCLASS_POLICY_REG(),0);
nf_PCI_write32(0,$batch, DRR_QCLASS_Q0_TOS_REG(),2);
nf_PCI_write32(0,$batch, DRR_QCLASS_Q1_TOS_REG(),0);
nf_PCI_write32(0,$batch, DRR_QCLASS_Q2_TOS_REG(),1);
nf_PCI_read32(150000,$batch, DRR_QCLASS_Q3_NUM_PKTS_REG(),4);


####################################################################
# Create  new packets 
# 

#forward through hw
my $delay = 50000;
my $length1 = 80;
my $DA = $f_port3;
my $SA = $f_randommac0;
my $ttl = 7;
my $dst_ip = $f_dstip0;
my $src_ip = $f_randomip0;
my $pkt1_send = make_IP_pkt($length1, $DA, $SA, $ttl, $dst_ip, $src_ip);

my $DA = $f_mac0;
my $SA = $f_port0;
my $ttl = 6;
my $dst_ip = $f_dstip0;
my $src_ip = $f_randomip0;
my $pkt1_exp = make_IP_pkt($length1, $DA, $SA, $ttl, $dst_ip, $src_ip);

my $delay = 50000;
my $length2 = 80;
my $DA = $f_port0;
my $SA = $f_randommac0;
my $ttl = 7;
my $dst_ip = $f_dstip1;
my $src_ip = $f_randomip0;
my $pkt2_send = make_IP_pkt($length2, $DA, $SA, $ttl, $dst_ip, $src_ip);


my $DA = $f_mac1;
my $SA = $f_port0;
my $ttl = 6;
my $dst_ip = $f_dstip1;
my $src_ip = $f_randomip0;
my $pkt2_exp = make_IP_pkt($length2, $DA, $SA, $ttl, $dst_ip, $src_ip);

nf_packet_in(4, $length1, $delay, $batch,  $pkt1_send);
nf_packet_in(1, $length2, $delay, $batch,  $pkt2_send);
nf_packet_in(4, $length1, 0, $batch,  $pkt1_send);
nf_packet_in(1, $length2, 0, $batch,  $pkt2_send);
nf_packet_in(4, $length1, 0, $batch,  $pkt1_send);
nf_packet_in(1, $length2, 0, $batch,  $pkt2_send);
nf_packet_in(4, $length1, 0, $batch,  $pkt1_send);
nf_packet_in(1, $length2, 0, $batch,  $pkt2_send);


nf_expected_packet($f_nextport0, $length1,             $pkt1_exp);
nf_expected_packet($f_nextport1, $length2,             $pkt2_exp);
nf_expected_packet($f_nextport1, $length2,             $pkt2_exp);
nf_expected_packet($f_nextport1, $length2,             $pkt2_exp);
nf_expected_packet($f_nextport0, $length1,             $pkt1_exp);
nf_expected_packet($f_nextport1, $length2,             $pkt2_exp);
nf_expected_packet($f_nextport0, $length1,             $pkt1_exp);
nf_expected_packet($f_nextport0, $length1,             $pkt1_exp);





# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


