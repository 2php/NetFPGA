#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

$delay = '@8us';
$batch = 0;

use NF::PacketGen;
use NF::PacketLib;
use SimLib;

use OpenFlowLib;
use NFOpenFlowTester;
use NFUtils::SimplePacket;
use reg_defines_tunneling_openflow_icmp_arp;

nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );
nf_add_port_rule(1, 'UNORDERED');
nf_add_port_rule(2, 'UNORDERED');
nf_add_port_rule(3, 'UNORDERED');
nf_add_port_rule(4, 'UNORDERED');

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

#my %cpci_regs = CPCI_Lib::get_register_addresses();

# write 0 to CPCI_INTERRUPT_MASK_REG()
#nf_PCI_write32(0, $batch, CPCI_INTERRUPT_MASK_REG(), 0);

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

####################################################################

# enable icmp reply
nf_PCI_write32(ICMP_REPLY_ENABLE_REG(), 1);

# set the port addresses
my @port_eth_addresses = ("00:00:00:00:00:01", "00:00:00:00:00:02", "00:00:00:00:00:03", "00:00:00:00:00:04");
my @src_eth_addresses = ("55:00:00:00:00:01", "55:00:00:00:00:02", "55:00:00:00:00:03", "55:00:00:00:00:04");
my @port_ip_addresses = (0x11111111, 0x22222222, 0x33333333, 0x44444444);
my @src_ip_addresses = (0x55555555, 0x66666666, 0x77777777, 0x88888888);
my $length = 64;
my $TTL = 16;
my $ICMP_REQ   = 0x8;
my $ICMP_REPLY = 0x0;
my $ICMP_CODE  = 0x0;
my $ICMP_ID    = 0x000f;
my $ICMP_SEQ   = 0x00fe;

my $i;
for($i=0; $i<4; $i++) {
  nf_PCI_write32(ICMP_REPLY_ETH_ADDR_PORT_0_LO_REG()+4*2*$i, $i+1);
  nf_PCI_write32(ICMP_REPLY_ETH_ADDR_PORT_0_HI_REG()+4*2*$i, 0);
  nf_PCI_write32(ICMP_REPLY_IP_ADDR_PORT_0_REG()+4*$i, $port_ip_addresses[$i]);
}

# create ICMP packets for all ports
my @pkts=();
my @resp_pkts=();
for($i=0; $i<4; $i++) {
  $pkts[$i] = NFOpenFlowTester::make_ICMP_pkt($length, $port_eth_addresses[$i], $src_eth_addresses[$i], $TTL, $port_ip_addresses[$i], $src_ip_addresses[$i], $ICMP_REQ, $ICMP_CODE, $ICMP_ID, $ICMP_SEQ);

  $resp_pkts[$i] = NFOpenFlowTester::make_ICMP_pkt($length, $src_eth_addresses[$i], $port_eth_addresses[$i], $TTL, $src_ip_addresses[$i], $port_ip_addresses[$i], $ICMP_REPLY, $ICMP_CODE, $ICMP_ID, $ICMP_SEQ);

}

# create ICMP pkts that don't match
$pkts[4] = NFOpenFlowTester::make_ICMP_pkt($length, $port_eth_addresses[$i], $src_eth_addresses[$i], $TTL, "10.10.10.10", $src_ip_addresses[$i], $ICMP_REPLY, $ICMP_CODE, $ICMP_ID, $ICMP_SEQ);

my $pkt_idx = 0;
my $port_idx = 0;

# now send pkts
for ($i=0; $i<44; $i++) {
  $pkt_idx = $i % 5;
  $port_idx = $i % 4;
  nf_packet_in($port_idx + 1, $length, '@24us', 0, $pkts[$pkt_idx]);
  nf_expected_packet($port_idx + 1, $length, $resp_pkts[$pkt_idx]) if defined $resp_pkts[$pkt_idx] && $pkt_idx == $port_idx;
}

# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');

