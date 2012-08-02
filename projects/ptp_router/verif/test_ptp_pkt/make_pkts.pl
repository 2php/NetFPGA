#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
# 

use NF2::Base "projects/reference_router/lib/Perl5";
use NF2::PacketGen;
use NF2::PacketLib;
use SimLib;
use RouterLib;

use reg_defines_ptp_router;

$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

my $ROUTER_PORT_1_MAC = '00:00:00:00:09:01';
my $ROUTER_PORT_2_MAC = '00:00:00:00:09:02';
my $ROUTER_PORT_3_MAC = '00:00:00:00:09:03';
my $ROUTER_PORT_4_MAC = '00:00:00:00:09:04';

my $ROUTER_PORT_1_IP = '192.168.26.2';
my $ROUTER_PORT_2_IP = '192.168.25.2';
my $ROUTER_PORT_3_IP = '192.168.27.1';
my $ROUTER_PORT_4_IP = '192.168.24.2';
my $OSPF_IP = '224.0.0.5';

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

# Write the ip addresses and mac addresses, routing table, filter, ARP entries
$delay = '@4us';
set_router_MAC(1, $ROUTER_PORT_1_MAC);
$delay = 0;
set_router_MAC(2, $ROUTER_PORT_2_MAC);
set_router_MAC(3, $ROUTER_PORT_3_MAC);
set_router_MAC(4, $ROUTER_PORT_4_MAC);

add_dst_ip_filter_entry(0,$ROUTER_PORT_1_IP);
add_dst_ip_filter_entry(1,$ROUTER_PORT_2_IP);
add_dst_ip_filter_entry(2,$ROUTER_PORT_3_IP);
add_dst_ip_filter_entry(3,$ROUTER_PORT_4_IP);
add_dst_ip_filter_entry(4,$OSPF_IP);

add_LPM_table_entry(0,'192.168.27.0', '255.255.255.0', '0.0.0.0', 0x10);
add_LPM_table_entry(1,'192.168.26.0', '255.255.255.0', '0.0.0.0', 0x01);
add_LPM_table_entry(2,'192.168.25.0', '255.255.255.0', '0.0.0.0', 0x04);
add_LPM_table_entry(3,'192.168.24.0', '255.255.255.0', '0.0.0.0', 0x40);

# Add the ARP table entries
add_ARP_table_entry(0, '192.168.25.1', '01:50:17:15:56:1c');
add_ARP_table_entry(1, '192.168.26.1', '01:50:17:20:fd:81');

my $length = 98;
my $TTL = 30;
my $DA = 0;
my $SA = 0;
my $dst_ip = 0;
my $src_ip = 0;
my $pkt;

#
###############################
#


##### PTP_hdr library ######
{
package NF2::PTP_hdr;

sub new   # PTP_hdr
 {
   my ($class,%arg) = @_;

   my $PTP_hdr = {
       'bytes' => [ # PTP,  hdr len = 34 bytes
           0x0,     # 0000MMMM where M is message type
           0x2,     # 0000VVVV where V is version (2 in our case)
           0x0, 0x22, # length (only header = 34 bytes)
           0x0,       # domain number
           0x0,       # reserved
           0x0, 0x0,    # flags (none set for now)
           0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,  # correction field (0x0 for now)
           0x0,0x0,0x0,0x0, # reserved
           0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0, # source port ID
           0x0, 0x0, # sequence id
           0x0, # control (deprecated in v2)
           0x0, # logmeanmessageinterval
           ]
   };

   bless $PTP_hdr, $class;

   # for now, message_type is only settable field
   $PTP_hdr->message_type($arg{'message_type'}) if (defined
$arg{'message_type'});

   $PTP_hdr;
 }

sub message_type
{
   my ($self, $val) = @_;

   if (defined $val) {
       my $err = sprintf "Message Type is %d (0x%01x) but it must be
>= 0 and <= 15", $val,$val;
       if (($val < 0) or ($val > 0xf)) { die "$err" }
       @{$self->{'bytes'}}[0] = $val;
   }
   return @{$self->{'bytes'}}[0];
}

sub bytes {
  my ($self) = @_;
  my @bytes =  @{$self->{'bytes'}};
  if (scalar(@bytes) > 0) {
    my @tmp = map {sprintf "%02x",$_} @{$self->{'bytes'}};
    return join(' ',@tmp).' ';
  }
  else {
    return "";
  }
}

sub length_in_bytes {
    my ($self) = @_;

    return (0+@{$self->{'bytes'}});
}


}
print "\nconstructing 1st packet....\n";

# 1st pkt (no VLAN)
        nf_PCI_write32(100,    $batch, COUNTER_3_REG(), 0x0001);
        nf_PCI_write32(0,      $batch, COUNTER_4_REG(), 0x0000);
        nf_PCI_write32(0,      $batch, COUNTER_3_4_LOAD_REG(), 0x1);
        nf_PCI_write32(0,      $batch, COUNTER_3_4_LOAD_REG(), 0x0);
     
        nf_PCI_write32(100,    $batch, COUNTER_1_REG(), 0x0);
        nf_PCI_write32(0,      $batch, COUNTER_2_REG(), 0x0);
        nf_PCI_write32(0,      $batch, COUNTER_1_2_LOAD_REG(), 0x1);
        nf_PCI_write32(0,      $batch, COUNTER_1_2_LOAD_REG(), 0x0);

        nf_PCI_write32(0,$batch, COUNTER_PTP_MASK_RX_REG(), 0xFF);
        nf_PCI_write32(0,$batch, COUNTER_PTP_MASK_TX_REG(), 0xF0);

for (my $i=0; $i<2; $i++){
	my $delay = '0';
	my $batch = 0;
        my $min_length = 60;

	# set parameters
	# PTP MAC broadcast address
	my $DA = "01:1B:19:00:00:00";
	my $SA = $ROUTER_PORT_2_MAC;
	my $PTP_ETHERTYPE = 0x88F7;

        nf_PCI_write32(0,$batch, COUNTER_READ_ENABLE_REG(), 0x1);
        nf_PCI_write32(0,$batch, COUNTER_READ_ENABLE_REG(), 0x0);
        nf_PCI_read32(0, $batch, COUNTER_BIT_95_64_REG(), 0x0);
        nf_PCI_read32(0, $batch, COUNTER_BIT_63_32_REG(), 0x3ff6);
        nf_PCI_read32(0, $batch, COUNTER_BIT_31_0_REG(), 0x0);

	# create mac header
	my $MAC_hdr = NF2::Ethernet_hdr->new(DA => $DA,
	                                     SA => $SA,
	                                     Ethertype => $PTP_ETHERTYPE
					     );

	my $PTP_TS_hdr = NF2::PTP_hdr->new(message_type => 3);
	my $PTP_NON_TS_hdr = NF2::PTP_hdr->new(message_type => 9);

        # pad packet (min length = 60 bytes)
        my $PDU = NF2::PDU->new($min_length - $MAC_hdr->length_in_bytes() - $PTP_TS_hdr->length_in_bytes());
        my $start_val = $MAC_hdr->length_in_bytes() + $PTP_TS_hdr->length_in_bytes() + 1;

        my @data = ($start_val..$min_length);
        for (@data) {$_ %= 100}
        $PDU->set_bytes(@data);

	# generate a packet that SHOULD get timestamped
        my $PTP_TS_pkt = $MAC_hdr->bytes() . $PTP_TS_hdr->bytes() . $PDU->bytes();
        print "ptp_ts_packet: ", $PTP_TS_pkt, "\n";

	# generate a packet that SHOULD NOT get timestamped
        my $PTP_NON_TS_pkt = $MAC_hdr->bytes() . $PTP_NON_TS_hdr->bytes() . $PDU->bytes();
        print "ptp_non_ts_packet: ", $PTP_NON_TS_pkt, "\n";

        print length($PTP_NON_TS_pkt);
        $delay = 800;

        nf_PCI_write32(0,$batch, COUNTER_READ_ENABLE_REG(), 0x1);
        nf_PCI_write32(0,$batch, COUNTER_READ_ENABLE_REG(), 0x0);
        nf_PCI_read32(0, $batch, COUNTER_BIT_95_64_REG(), 0x0);
        nf_PCI_read32(0, $batch, COUNTER_BIT_63_32_REG(), 0x4ce6);
        nf_PCI_read32(0, $batch, COUNTER_BIT_31_0_REG(), 0x0);

	# verifies that NO TS packets don't get timestamped....
        print "@@@@@@@@@@@ send packet one\n";

        nf_packet_in(1, $min_length, $delay, $batch, $PTP_NON_TS_pkt);
       	# TODO: verify no timestamp done
	
        print "@@@@@@@@@@@ send packet two\n";
        $delay = 80100;
	# verifies that TS packets don't get timestamped....
	nf_packet_in(1, $min_length, $delay, $batch,  $PTP_TS_pkt);
	# TODO: verify packet timestampe
        
        nf_PCI_write32(1000,$batch, COUNTER_READ_ENABLE_REG(), 0x1);
        nf_PCI_write32(0,$batch, COUNTER_READ_ENABLE_REG(), 0x0);
        nf_PCI_read32(0, $batch, COUNTER_BIT_95_64_REG(), 0x0);
        nf_PCI_read32(0, $batch, COUNTER_BIT_63_32_REG(), 0x59b2);
        nf_PCI_read32(0, $batch, COUNTER_BIT_31_0_REG(), 0x0);


	nf_PCI_write32(150000,$batch, COUNTER_PTP_MASK_RX_REG(), 0xFE);
        nf_PCI_read32(0, $batch, COUNTER_PTP_VALID_RX_REG(), 0x01);
        nf_PCI_write32(0,$batch, COUNTER_PTP_ENABLE_MASK_RX_REG(), 0x01);
        nf_PCI_write32(0,$batch, COUNTER_PTP_ENABLE_MASK_RX_REG(), 0x0);
        nf_PCI_read32(0, $batch, COUNTER_PTP_VALID_RX_REG(), 0x0);

        nf_PCI_read32(160000, $batch, COUNTER_CLK_SYN_0_RX_LO_REG(), 0x663ab9);
        nf_PCI_read32(0, $batch, COUNTER_CLK_SYN_0_RX_HI_REG(), 0x43ffbc);

        nf_PCI_read32(0, $batch, COUNTER_CLK_SYN_1_RX_LO_REG(), 0x0);
        nf_PCI_read32(0, $batch, COUNTER_CLK_SYN_1_RX_HI_REG(), 0x0);

				if ($i==1){
			  my $queue = 1;
	  		nf_expected_dma_data($queue, $min_length, $PTP_NON_TS_pkt);
			  nf_expected_dma_data($queue, $min_length, $PTP_TS_pkt);
				}

      }



        $delay = '@4us';
# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
