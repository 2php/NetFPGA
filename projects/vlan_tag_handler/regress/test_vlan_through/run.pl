#!/usr/bin/perl

use strict;
use TaggingRegLib; # necessary libraries are included in this lib

use constant NUM_PKTS => 200;

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

my $i = 0;
my @vlan_id = ();
for ($i = 0; $i < 4; $i++)
{
	$vlan_id[$i] = int(rand(65533)) + 1;
}

my $vlan_through = 0x0;
nftest_regwrite('nf2c0', VLAN_ADDER_0_VLAN_TAG_REG(), $vlan_through);
nftest_regwrite('nf2c0', VLAN_ADDER_1_VLAN_TAG_REG(), $vlan_through);
nftest_regwrite('nf2c0', VLAN_ADDER_2_VLAN_TAG_REG(), $vlan_through);
nftest_regwrite('nf2c0', VLAN_ADDER_3_VLAN_TAG_REG(), $vlan_through);

`sleep 1`;

my $vlan_id_snd = $vlan_id[1];
my $vlan_id_exp = $vlan_id_snd;

# loop until <NUM_PKTS> number of packets from eth1 to eth2
for ($i = 0; $i < NUM_PKTS; $i++)
{
	send_and_expect_pkt('eth1', 'eth2', $vlan_id_snd, $vlan_id_exp);
}
`sleep 1`;

$vlan_id_snd = $vlan_id[0];
$vlan_id_exp = $vlan_id_snd;

# loop until <NUM_PKTS> number of packets from eth2 to eth1
for ($i = 0; $i < NUM_PKTS; $i++)
{
	send_and_expect_pkt('eth2', 'eth1', $vlan_id_snd, $vlan_id_exp);
}
`sleep 1`;

# Check errors below

my $unmatched_hoh = nftest_finish();

my $total_errors = 0;

print "Checking pkt errors\n";
$total_errors += nftest_print_errors($unmatched_hoh);

# check counter values
for (my $port = 0; $port < 2; $port++) {
	$total_errors += mac_queue_check($port, NUM_PKTS);
}

if ($total_errors==0) {
  print "SUCCESS!\n";
  exit 0;
}
else {
  print "Test FAILED: $total_errors errors\n";
  exit 1;
}

