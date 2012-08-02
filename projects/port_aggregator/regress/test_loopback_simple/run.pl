#!/usr/bin/perl

use strict;

use TaggingRegLib; # necessary libraries are included in this lib

use constant NUM_PKTS => 3000;
use constant MAX_LENGTH => 80;
use constant MIN_LENGTH => 80;

my $total_errors = 0;

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3");
nftest_init(\@ARGV,\@interfaces,);
nftest_start(\@interfaces);

nftest_fpga_reset('nf2c0');

# Put ports into loopback mode
nftest_phy_loopback('nf2c0');
nftest_phy_loopback('nf2c1');
nftest_phy_loopback('nf2c2');
nftest_phy_loopback('nf2c3');

nftest_regread_expect('nf2c0', MDIO_PHY_0_CONTROL_REG(), 0x5140);
nftest_regread_expect('nf2c0', MDIO_PHY_1_CONTROL_REG(), 0x5140);
nftest_regread_expect('nf2c0', MDIO_PHY_2_CONTROL_REG(), 0x5140);
nftest_regread_expect('nf2c0', MDIO_PHY_3_CONTROL_REG(), 0x5140);

# set it up so that you send each packet to corresponding DMA-PORT
for(my $i=0; $i<4; $i++) {
  nftest_regwrite('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+$i*2*4, 1<<($i*2+1));
  nftest_regwrite('nf2c0', HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+($i*2+1)*4, 1<<($i*2));
}

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

nftest_regwrite('nf2c0', VLAN_ADDER_0_VLAN_TAG_REG(), $vlan_tag[0]);
nftest_regwrite('nf2c0', VLAN_ADDER_1_VLAN_TAG_REG(), $vlan_tag[1]);
nftest_regwrite('nf2c0', VLAN_ADDER_2_VLAN_TAG_REG(), $vlan_tag[2]);
nftest_regwrite('nf2c0', VLAN_ADDER_3_VLAN_TAG_REG(), $vlan_tag[3]);
#verify the values above
$total_errors += nftest_reg_compare('nf2c0', VLAN_ADDER_0_VLAN_TAG_REG(), $vlan_tag[0]);
$total_errors += nftest_reg_compare('nf2c0', VLAN_ADDER_1_VLAN_TAG_REG(), $vlan_tag[1]);
$total_errors += nftest_reg_compare('nf2c0', VLAN_ADDER_2_VLAN_TAG_REG(), $vlan_tag[2]);
$total_errors += nftest_reg_compare('nf2c0', VLAN_ADDER_3_VLAN_TAG_REG(), $vlan_tag[3]);

`sleep 1`;

# set parameters
my $DA = "00:ca:fe:00:00:01";
my $SA = "aa:bb:cc:dd:ee:ff";
my $TTL = 64;
my $DST_IP = "192.168.1.1";
my $SRC_IP = "192.168.0.1";;
my $nextHopMAC = "dd:55:dd:66:dd:77";

# create mac header
my $MAC_hdr = NF2::Ethernet_hdr->new(DA => $DA,
                                     SA => $SA,
                                     Ethertype => 0x800
                                    );

#create IP header
my $IP_hdr = NF2::IP_hdr->new(ttl => $TTL,
                              src_ip => $SRC_IP,
                              dst_ip => $DST_IP
                             );

$IP_hdr->checksum(0);  # make sure its zero before we calculate it.
$IP_hdr->checksum($IP_hdr->calc_checksum);

my $num_precreated = 1000;
my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes()+1;

# precreate random sized packets
$MAC_hdr->DA("00:ca:fe:00:00:01");
my @precreated0 = nftest_precreate_ip_pkts($num_precreated, $MAC_hdr, $IP_hdr, MIN_LENGTH, MAX_LENGTH);
$MAC_hdr->DA("00:ca:fe:00:00:02");
my @precreated1 = nftest_precreate_ip_pkts($num_precreated, $MAC_hdr, $IP_hdr, MIN_LENGTH, MAX_LENGTH);
$MAC_hdr->DA("00:ca:fe:00:00:03");
my @precreated2 = nftest_precreate_ip_pkts($num_precreated, $MAC_hdr, $IP_hdr, MIN_LENGTH, MAX_LENGTH);
$MAC_hdr->DA("00:ca:fe:00:00:04");
my @precreated3 = nftest_precreate_ip_pkts($num_precreated, $MAC_hdr, $IP_hdr, MIN_LENGTH, MAX_LENGTH);

print "Sending now: \n";
my $pkt;
my $outport_val;
my @totalPktLengths = (0, 0, 0, 0);
# send NUM_PKTS packets from ports nf2c0...nf2c3
for(my $i=0; $i<NUM_PKTS; $i++){
  print "$i \r";

  $outport_val = 0;
  nftest_regwrite('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);
  $total_errors += nftest_reg_compare('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);
  $pkt = $precreated0[int(rand($num_precreated))];
  $totalPktLengths[0] += length($pkt);
  nftest_send('nf2c0', $pkt);
  nftest_expect('nf2c0', $pkt);
        
  $outport_val = 1;
  nftest_regwrite('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);
  $total_errors += nftest_reg_compare('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);
  $pkt = $precreated1[int(rand($num_precreated))];
  $totalPktLengths[1] += length($pkt);
  nftest_send('nf2c1', $pkt);
  nftest_expect('nf2c1', $pkt);
        
  $outport_val = 2;
  nftest_regwrite('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);
  $total_errors += nftest_reg_compare('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);
  $pkt = $precreated2[int(rand($num_precreated))];
  $totalPktLengths[2] += length($pkt);
  nftest_send('nf2c2', $pkt);
  nftest_expect('nf2c2', $pkt);

  $outport_val = 3;
  nftest_regwrite('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);
  $total_errors += nftest_reg_compare('nf2c0', OUT_AGGR_OUTPORT_REG(), $outport_val);
  $pkt = $precreated3[int(rand($num_precreated))];
  $totalPktLengths[3] += length($pkt);
  nftest_send('nf2c3', $pkt);
  nftest_expect('nf2c3', $pkt);
}

print "\n";

`sleep 1`;

my $unmatched_hoh = nftest_finish();
nftest_reset_phy();

print "Checking pkt errors\n";
$total_errors += nftest_print_errors($unmatched_hoh);

# check counter values
for (my $port = 0; $port < 4; $port++) {
  $total_errors += mac_queue_check($port, NUM_PKTS);
}
 
if ($total_errors==0) {
  print "Test PASSES\n";
  exit 0;
}
else {
  print "Test FAILED: $total_errors errors\n";
  exit 1;
}
