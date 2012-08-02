#!/usr/bin/perl

use strict;
use NF2::Base "projects/reference_router/lib/Perl5";
use NF2::RegressLib;
use NF2::PacketLib;
use RegressRouterLib;

use reg_defines_rcp_router;

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2");
nftest_init(\@ARGV, \@interfaces);
nftest_start(\@interfaces);

nftest_fpga_reset('nf2c0');

my $routerMAC0 = "00:ca:fe:00:00:01";
my $routerMAC1 = "00:ca:fe:00:00:02";
my $routerMAC2 = "00:ca:fe:00:00:03";
my $routerMAC3 = "00:ca:fe:00:00:04";

my $routerIP0 = "192.168.0.40";
my $routerIP1 = "192.168.1.40";
my $routerIP2 = "192.168.2.40";
my $routerIP3 = "192.168.3.40";

# Write the mac and IP addresses
nftest_add_dst_ip_filter_entry ('nf2c0', 0, $routerIP0);
nftest_add_dst_ip_filter_entry ('nf2c1', 1, $routerIP1);
nftest_add_dst_ip_filter_entry ('nf2c2', 2, $routerIP2);
nftest_add_dst_ip_filter_entry ('nf2c3', 3, $routerIP3);

nftest_set_router_MAC ('nf2c0', $routerMAC0);
nftest_set_router_MAC ('nf2c1', $routerMAC1);
nftest_set_router_MAC ('nf2c2', $routerMAC2);
nftest_set_router_MAC ('nf2c3', $routerMAC3);

# add an entry in the routing table:
my $index = 0;
my $subnetIP = "192.168.1.0";
my $subnetIP2 = "192.168.1.1";
my $subnetMask = "255.255.255.0";
my $subnetMask2 = "255.255.255.225";
my $nextHopIP = "192.168.1.54";
my $nextHopIP2 = "0.0.0.0";
my $outPort = 0x1; # output on MAC0
my $outPort2 = 0x4;
my $nextHopMAC = "dd:55:dd:66:dd:77";

nftest_add_LPM_table_entry ('nf2c0',
			    1,
			    $subnetIP,
			    $subnetMask,
			    $nextHopIP,
			    $outPort);

nftest_add_LPM_table_entry ('nf2c0',
			    0,
			    $subnetIP2,
			    $subnetMask2,
			    $nextHopIP2,
			    $outPort2);


# add an entry in the ARP table
nftest_add_ARP_table_entry('nf2c0',
			   $index,
			   $nextHopIP,
			   $nextHopMAC);

# add an entry in the ARP table
nftest_add_ARP_table_entry('nf2c0',
			   1,
			   $subnetIP2,
			   $nextHopMAC);

my $total_errors = 0;

# set RCP parameters
my $fwd = 0xddcc;
my $rev = 0x1;
my $rtt = 0xfb;
my $proto = 0xfe;
my $len = 1000;
my $router_rate = 0xabc;

my $num_packet = 20;
nftest_regwrite("nf2c0", RCP_RATE_1_REG(), $router_rate);
nftest_regwrite("nf2c0", RCP_RATE_0_REG(), 0xaaa);
nftest_regwrite("nf2c0", RCP_RATE_2_REG(), 0xbbb);
nftest_regwrite("nf2c0", RCP_RATE_3_REG(), 0xccc);
nftest_regwrite("nf2c0", RCP_MAC_1_RTT_LO_REG(), 0);
nftest_regwrite("nf2c0", RCP_MAC_1_RTT_HI_REG(), 0);
nftest_regwrite("nf2c0", RCP_MAC_1_NUM_RCP_REG(), 0);
nftest_regwrite("nf2c0", RCP_MAC_1_NUM_BYTES_LO_REG(), 0);
nftest_regwrite("nf2c0", RCP_MAC_1_NUM_BYTES_HI_REG(), 0);


sleep 1;
# loop for num_packet packets sending LPM miss packet
for (my $i = 0; $i < $num_packet; $i++)
{
	# set parameters
	my $DA = $routerMAC0;
	my $SA = "aa:bb:cc:dd:ee:ff";
	my $TTL = 64;
	my $DST_IP = "192.168.1.1"; 
	my $SRC_IP = "192.168.0.1";
	my $DST_IP_tun = "162.158.1.1";
        my $SRC_IP_tun = "162.158.1.0";
	
	my $nextHopMAC = "dd:55:dd:66:dd:77";

	# create mac header
	my $MAC_hdr = NF2::Ethernet_hdr->new(DA => $DA,
						     SA => $SA,
						     Ethertype => 0x800
				    		);

	#create IP header
	my $IP_hdr = NF2::IP_hdr->new(ttl => $TTL,
				      src_ip => $SRC_IP,
				      dst_ip => $DST_IP,
				      proto  => $proto
				     );

	$IP_hdr->checksum(0);  # make sure its zero before we calculate it.
	$IP_hdr->checksum($IP_hdr->calc_checksum);

	#creat RCP header
	my $RCP_hdr = NF2::RCP_hdr->new(fwd => $fwd,
					rev => $rev,
					rtt => $rtt,
					proto => $proto
				       );

	# create packet filling.... (IP PDU)
	my $PDU = NF2::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->length_in_bytes() - $RCP_hdr->length_in_bytes());
	my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes() + $RCP_hdr->length_in_bytes()+1;
	my @data = ($start_val..$len);
	for (@data) {$_ %= 100}
	$PDU->set_bytes(@data);
	
	# Return complete packet data
	my $sent_pkt = $MAC_hdr->packed.$IP_hdr->packed.$RCP_hdr->packed.$PDU->packed;
        my $unpacked_pkt = unpack('H*', $sent_pkt);
        #print "packet sent in:\n $unpacked_pkt \n";

	# create the expected packet
	my $MAC_hdr2 = NF2::Ethernet_hdr->new(DA => $nextHopMAC,
						     SA => $routerMAC1,
						     Ethertype => 0x800
				    		);


	$IP_hdr->ttl($TTL-1);
	$IP_hdr->checksum(0);  # make sure its zero before we calculate it.
	$IP_hdr->checksum($IP_hdr->calc_checksum);

	#creat RCP header
	#if ($router_rate < $rtt){
	 my $RCP_hdr2 = NF2::RCP_hdr->new(fwd => $router_rate,
					  rev => $rev,
					  rtt => $rtt,
					  proto => $proto
					 );
	
        #}
	my $expected_pkt = $MAC_hdr2->packed . $IP_hdr->packed . $RCP_hdr2->packed. $PDU->packed;
	my $unpacked_pkt = unpack('H*', $expected_pkt);
	#print "packet  coming out:\n $unpacked_pkt \n";
	# send packet out of eth1->nf2c0 
	nftest_send('eth1', $sent_pkt);
	nftest_expect('eth2', $expected_pkt);
  
}

sleep 3;
# read the RCP registers
if (nftest_regread_expect("nf2c0", RCP_MAC_1_RTT_LO_REG(), $num_packet * $rtt) != $num_packet * $rtt) {
	$total_errors++;
}
if (nftest_regread_expect("nf2c0", RCP_MAC_1_RTT_HI_REG(), 0) != 0){
	$total_errors++;
}
if (nftest_regread_expect("nf2c0", RCP_MAC_1_NUM_RCP_REG(), $num_packet) != $num_packet) {
	$total_errors++;
}
if (nftest_regread_expect("nf2c0", RCP_MAC_1_NUM_BYTES_LO_REG(), $num_packet *$len ) != $num_packet * $len) {
	$total_errors++;
}
if (nftest_regread_expect("nf2c0", RCP_MAC_1_NUM_BYTES_HI_REG(), 0) != 0) {
	$total_errors++;
}

sleep 1;
my $unmatched_hoh = nftest_finish();
$total_errors += nftest_print_errors($unmatched_hoh);

if ($total_errors==0) {
  print "SUCCESS!\n";
	exit 0;
}
else {
  print "FAIL: $total_errors errors\n";
	exit 1;
}
