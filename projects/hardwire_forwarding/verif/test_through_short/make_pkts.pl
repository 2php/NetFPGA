#!/usr/local/bin/perl -w
# make_pkts.pl
#

use NF2::PacketGen;
use NF2::PacketLib;
use SimLib;

use reg_defines_hardwire_forwarding;

$delay = '@4us';
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

my $length = 100;
my $DA_sub = ':dd:dd:dd:dd:dd';
my $SA_sub = ':55:55:55:55:55';
my $DA;
my $SA;
my $pkt;
my $in_port;
my $exp_port;
my $i = 0;
my $j = 0;
my $temp;
my $type;

$delay = '@6us';
# set up the output port so that you send each packet out the next port
for($i=0; $i<8; $i++) {
  nf_PCI_write32($delay, 0, HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+$i*4, 1<<(($i+2)%8));
}

# Set the packet length as small/large/random size.
# send and receive pkts to each port
$delay = '@17us';
for($j=0; $j<15; $j++){
  if ($j < 5){
    $length = 60;
  } elsif($j < 10){
    $length = 1500;
  } else {
    $length = 60 + int(rand(1440));
  }
  # send and receive 3 pkts into each port
  for($i=0; $i<12; $i++){
    $temp = sprintf("%02x", $i);
    $DA = $temp . $DA_sub;
    $SA = $temp . $SA_sub;
    $in_port = ($i%4) + 1;
    $exp_port = ($in_port%4)+1;
    $type = 0x0800;

    $pkt = make_ethernet_pkt($length, $DA, $SA, $type);

    nf_packet_in($in_port, $length, $delay, $batch, $pkt);
    nf_expected_packet($exp_port, $length, $pkt);
  }
}

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
