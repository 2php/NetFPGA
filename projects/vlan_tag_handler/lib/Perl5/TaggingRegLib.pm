#####################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id$
# author: Tatsuya Yabe tyabe@stanford.edu
#
#####################################

#######################################################
package main;
use reg_defines_vlan_tag_handler;
#######################################################
use strict;

use NF2::RegressLib;
use NF2::PacketLib;

sub send_and_expect_pkt {
  my ($snd, $rcv, $vlan_id_snd, $vlan_id_exp) = @_;

  # set parameters
  my @MAC = ();
  $MAC[0] = "00:ca:fe:00:00:01";
  $MAC[1] = "00:ca:fe:00:00:02";
  $MAC[2] = "00:ca:fe:00:00:03";
  $MAC[3] = "00:ca:fe:00:00:04";
  my $TTL = 64;
  my $DST_IP = "192.168.111.1"; 
  my $SRC_IP = "192.168.0.1";
  my $len = int(rand(1440)) + 60;

  #create MAC headers
  my $MAC_hdr_snd;
  my $MAC_hdr_exp;

  # Prepare mac address from the above list at random
  my $mac_sa = int(rand(4));
  my $mac_da = ($mac_sa + 1) % 4;

  if($vlan_id_snd == 0) {
    $MAC_hdr_snd = NF2::Ethernet_hdr->new(DA => $MAC[$mac_da],
                                          SA => $MAC[$mac_sa],
                                          Ethertype => 0x800
                                         );
  } else {
    $MAC_hdr_snd = NF2::VLAN_hdr->new(DA => $MAC[$mac_da],
                                      SA => $MAC[$mac_sa],
                                      Ethertype => 0x800,
                                      VLAN_ID => $vlan_id_snd
                                     );
  }
  if($vlan_id_exp == 0) {
    $MAC_hdr_exp = NF2::Ethernet_hdr->new(DA => $MAC[$mac_da],
                                          SA => $MAC[$mac_sa],
                                          Ethertype => 0x800
                                         );
  } else {
    $MAC_hdr_exp = NF2::VLAN_hdr->new(DA => $MAC[$mac_da],
                                      SA => $MAC[$mac_sa],
                                      Ethertype => 0x800,
                                      VLAN_ID => $vlan_id_exp
                                     );
  }

  #create IP header
  my $IP_hdr = NF2::IP_hdr->new(ttl => $TTL,
                                src_ip => $SRC_IP,
                                dst_ip => $DST_IP
 	                             );
  $IP_hdr->checksum(0);  # make sure its zero before we calculate it.
  $IP_hdr->checksum($IP_hdr->calc_checksum);

  # create packet filling.... (IP PDU)
  my $PDU = NF2::PDU->new($len - $MAC_hdr_snd->length_in_bytes() - $IP_hdr->length_in_bytes() );
  my $start_val = $MAC_hdr_snd->length_in_bytes() + $IP_hdr->length_in_bytes()+1;
  my @data = ($start_val..$len);
  for (@data) {$_ %= 100}
  $PDU->set_bytes(@data);

  # get packed packet string
  my $sent_pkt = $MAC_hdr_snd->packed . $IP_hdr->packed . $PDU->packed;

  # create the expected packet

  # get packed packet string
  my $expected_pkt = $MAC_hdr_exp->packed . $IP_hdr->packed . $PDU->packed;

  # send packet out of the port as in snd to nf2c0 
  # expect packet on the port as in rcv
  nftest_send($snd, $sent_pkt);
  nftest_expect($rcv, $expected_pkt);

  `usleep 500`;
}

sub mac_queue_check {
 my ($port, $expected_count) = @_;

        my $reg_data = 0;
        my $total_errors = 0;
        $reg_data = nftest_regread_expect("nf2c0", MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG() + $port * 0x40000, $expected_count);

        if ($reg_data != $expected_count) {
                $total_errors++;
                print "ERROR: MAC Queue $port counters are wrong\n";
                print "   Rx pkts stored: $reg_data     expected: " . $expected_count . "\n";
        }       

        $reg_data = nftest_regread_expect("nf2c0", MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG() + $port * 0x40000, $expected_count);

        if ($reg_data != $expected_count) {
                $total_errors++;
                print "ERROR: MAC Queue $port counters are wrong\n";
                print "   Tx pkts sent: $reg_data       expected: " . $expected_count . "\n";
        }
	return $total_errors;
}

1;
