#!/usr/bin/perl

use strict;
use TaggingRegLib; # necessary libraries are included in this lib

use constant NUM_PKTS => 200;

my $total_errors = 0;

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2");
nftest_init(\@ARGV,\@interfaces,);
nftest_start(\@interfaces);

nftest_fpga_reset('nf2c0');

# Hardware forwarding register setup
# nf2c0-nf2c1, nf2c2-nf2c3
nftest_regwrite('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+ 4*0, 1<<2);
nftest_regwrite('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+ 4*2, 1<<0);
nftest_regwrite('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+ 4*4, 1<<6);
nftest_regwrite('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+ 4*6, 1<<4);
# verify the values above
$total_errors += nftest_reg_compare('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+ 4*0, 1<<2);
$total_errors += nftest_reg_compare('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+ 4*2, 1<<0);
$total_errors += nftest_reg_compare('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+ 4*4, 1<<6);
$total_errors += nftest_reg_compare('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+ 4*6, 1<<4);

# Initialize and setup VLAN tag values for testing
my @vlan_tag = ();
for(my $i=0; $i<4; $i++) {
  $vlan_tag[$i] = int(rand(4093)) + 1;
}

#Setup VID value for each input port
nftest_regwrite('nf2c0', VLAN_REMOVER_INPORT_0_VLAN_TAG_REG(), $vlan_tag[0]);
nftest_regwrite('nf2c0', VLAN_REMOVER_INPORT_1_VLAN_TAG_REG(), $vlan_tag[1]);
nftest_regwrite('nf2c0', VLAN_REMOVER_INPORT_2_VLAN_TAG_REG(), $vlan_tag[2]);
nftest_regwrite('nf2c0', VLAN_REMOVER_INPORT_3_VLAN_TAG_REG(), $vlan_tag[3]);
#verify the values above
$total_errors += nftest_reg_compare('nf2c0', VLAN_REMOVER_INPORT_0_VLAN_TAG_REG(), $vlan_tag[0]);
$total_errors += nftest_reg_compare('nf2c1', VLAN_REMOVER_INPORT_1_VLAN_TAG_REG(), $vlan_tag[1]);
$total_errors += nftest_reg_compare('nf2c2', VLAN_REMOVER_INPORT_2_VLAN_TAG_REG(), $vlan_tag[2]);
$total_errors += nftest_reg_compare('nf2c3', VLAN_REMOVER_INPORT_3_VLAN_TAG_REG(), $vlan_tag[3]);

my $vlan_through = 0x0;
nftest_regwrite('nf2c0', VLAN_ADDER_0_VLAN_TAG_REG(), $vlan_through);
nftest_regwrite('nf2c0', VLAN_ADDER_1_VLAN_TAG_REG(), $vlan_through);
nftest_regwrite('nf2c0', VLAN_ADDER_2_VLAN_TAG_REG(), $vlan_through);
nftest_regwrite('nf2c0', VLAN_ADDER_3_VLAN_TAG_REG(), $vlan_through);
#verify the values above
$total_errors += nftest_reg_compare('nf2c0', VLAN_ADDER_0_VLAN_TAG_REG(), $vlan_through);
$total_errors += nftest_reg_compare('nf2c0', VLAN_ADDER_1_VLAN_TAG_REG(), $vlan_through);
$total_errors += nftest_reg_compare('nf2c0', VLAN_ADDER_2_VLAN_TAG_REG(), $vlan_through);
$total_errors += nftest_reg_compare('nf2c0', VLAN_ADDER_3_VLAN_TAG_REG(), $vlan_through);

# Specify output port
# (Random value. The packets should not come to the port anyway.)
my $outport_val = int(rand(4));
nftest_regwrite('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);
$total_errors += nftest_reg_compare('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);

`sleep 1`;

my $vlan_id_snd = 0x0000;
# loop until <NUM_PKTS> number of packets from eth1 to eth2
for (my $i = 0; $i < NUM_PKTS; $i++)
{
  send_pkt('eth1', 'eth2', $vlan_id_snd);
}
`sleep 1`;

$vlan_id_snd = 0x0000;
# loop until <NUM_PKTS> number of packets from eth2 to eth1
for (my $i = 0; $i < NUM_PKTS; $i++)
{
  send_pkt('eth2', 'eth1', $vlan_id_snd);
}
`sleep 1`;

# Check errors below

# Check packets have been received on incoming ports
$total_errors += nftest_reg_compare('nf2c0', MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG(), NUM_PKTS);
$total_errors += nftest_reg_compare('nf2c0', MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG(), NUM_PKTS);
$total_errors += nftest_reg_compare('nf2c0', MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG(), 0);

# Chek if no packets have reached output_queues
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_0_NUM_PKTS_RECEIVED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_0_NUM_PKTS_DROPPED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_1_NUM_PKTS_RECEIVED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_1_NUM_PKTS_DROPPED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_2_NUM_PKTS_RECEIVED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_2_NUM_PKTS_DROPPED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_3_NUM_PKTS_RECEIVED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_3_NUM_PKTS_DROPPED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_4_NUM_PKTS_RECEIVED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_4_NUM_PKTS_DROPPED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_5_NUM_PKTS_RECEIVED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_5_NUM_PKTS_DROPPED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_6_NUM_PKTS_RECEIVED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_6_NUM_PKTS_DROPPED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_7_NUM_PKTS_RECEIVED_REG(), 0);
$total_errors += nftest_reg_compare('nf2c0', BRAM_OQ_QUEUE_7_NUM_PKTS_DROPPED_REG(), 0);

my $unmatched_hoh = nftest_finish();

print "Checking pkt errors\n";
$total_errors += nftest_print_errors($unmatched_hoh);

if ($total_errors==0) {
  print "SUCCESS!\n";
  exit 0;
}
else {
  print "Test FAILED: $total_errors errors\n";
  exit 1;
}

