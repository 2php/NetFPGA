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

# enable arp reply
nf_PCI_write32(ARP_REPLY_ENABLE_REG(), 1);

# set the port addresses
my @port_eth_addresses = ("00:00:00:00:00:01", "00:00:00:00:00:02", "00:00:00:00:00:03", "00:00:00:00:00:04");
my @src_addresses = ("55:00:00:00:00:01", "55:00:00:00:00:02", "55:00:00:00:00:03", "55:00:00:00:00:04");
my @port_ip_addresses = (0x11111111, 0x22222222, 0x33333333, 0x44444444);
my $i;
for($i=0; $i<4; $i++) {
  nf_PCI_write32(ARP_REPLY_ETH_ADDR_PORT_0_LO_REG()+4*2*$i, $i+1);
  nf_PCI_write32(ARP_REPLY_ETH_ADDR_PORT_0_HI_REG()+4*2*$i, 0);
  nf_PCI_write32(ARP_REPLY_IP_ADDR_PORT_0_REG()+4*$i, $port_ip_addresses[$i]);
}

# create ARP packets for all ports
my @pkts=();
my @resp_pkts=();
for($i=0; $i<4; $i++) {
  $pkts[$i] = NFUtils::SimplePacket->new(NFUtils::SimplePacket::PKT_TYPE() => NFUtils::SimplePacket::PKT_TYPE_ARP(),
                                         NFUtils::SimplePacket::ARP_OPCODE() => NFUtils::SimplePacket::ARP_OPCODE_REQUEST(),
					 NFUtils::SimplePacket::ETH_SRC() => $src_addresses[$i],
					 NFUtils::SimplePacket::ARP_SRC_HW() => $src_addresses[$i],
					 NFUtils::SimplePacket::PAYLOAD_GEN() => sub {return 0},
                                         NFUtils::SimplePacket::ARP_DST_IP() => $port_ip_addresses[$i]);

  $resp_pkts[$i] = NFUtils::SimplePacket->new(NFUtils::SimplePacket::PKT_TYPE() => NFUtils::SimplePacket::PKT_TYPE_ARP(),
					      NFUtils::SimplePacket::ETH_DST() => $pkts[$i]->get(NFUtils::SimplePacket::ETH_SRC),
					      NFUtils::SimplePacket::ETH_SRC() => $port_eth_addresses[$i],
                                              NFUtils::SimplePacket::ARP_OPCODE() => NFUtils::SimplePacket::ARP_OPCODE_REPLY(),
                                              NFUtils::SimplePacket::ARP_SRC_HW() => $port_eth_addresses[$i],
                                              NFUtils::SimplePacket::ARP_SRC_IP() => $port_ip_addresses[$i],
                                              NFUtils::SimplePacket::ARP_DST_HW() => $pkts[$i]->get(NFUtils::SimplePacket::ARP_SRC_HW),
                                              NFUtils::SimplePacket::ARP_DST_IP() => $pkts[$i]->get(NFUtils::SimplePacket::ARP_SRC_IP),
					      NFUtils::SimplePacket::PAYLOAD_GEN() => sub {return 0});
}

# create ARP pkts that don't match
$pkts[4] = NFUtils::SimplePacket->new(NFUtils::SimplePacket::PKT_TYPE() => NFUtils::SimplePacket::PKT_TYPE_ARP(),
                                      NFUtils::SimplePacket::ARP_OPCODE() => NFUtils::SimplePacket::ARP_OPCODE_REQUEST(),
                                      NFUtils::SimplePacket::ARP_DST_IP() => "10.10.10.10");

$pkts[5] = NFUtils::SimplePacket->new(NFUtils::SimplePacket::PKT_TYPE() => NFUtils::SimplePacket::PKT_TYPE_ARP(),
                                      NFUtils::SimplePacket::ARP_OPCODE() => NFUtils::SimplePacket::ARP_OPCODE_REPLY(),
                                      NFUtils::SimplePacket::ARP_DST_IP() => $port_ip_addresses[1]);

# create normal pkts
$pkts[6] = NFUtils::SimplePacket->new(NFUtils::SimplePacket::PKT_TYPE() => NFUtils::SimplePacket::PKT_TYPE_UDP());

# now send pkts
for ($i=0; $i<44; $i++) {
  my $pkt_idx = $i % 7;
  my $port_idx = $i % 4;
  my $pkt = $pkts[$pkt_idx];
  nf_packet_in($port_idx + 1, $pkt->get(NFUtils::SimplePacket::PKT_LEN), '@24us', 0, $pkt->hexBytes());
  nf_expected_packet($port_idx + 1, $resp_pkts[$pkt_idx]->get(NFUtils::SimplePacket::PKT_LEN), $resp_pkts[$pkt_idx]->hexBytes()) if defined $resp_pkts[$pkt_idx] && $pkt_idx == $port_idx;
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


