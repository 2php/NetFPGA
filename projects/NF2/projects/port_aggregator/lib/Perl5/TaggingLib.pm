#####################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id$
# author: Tatsuya Yabe tyabe@stanford.edu
#
#####################################

#######################################################
package main;
use reg_defines_port_aggregator;
#######################################################
use strict;
use POSIX;

use NF2::PacketGen;
use NF2::PacketLib;

sub make_vlan_pkt { # len, DA, SA, vlan_tag

  my ($len, $DA, $SA, $vlan_tag) = @_;
  my $type = 0x0800;
  my $tag_len = 4;

  my $MAC_hdr = NF2::VLAN_hdr->new(DA => $DA,
                                   SA => $SA,
                                   Ethertype => $type,
                                   VLAN_ID => $vlan_tag
                                   );

  my $PDU = NF2::PDU->new($len - $MAC_hdr->length_in_bytes());
  my $start_val = $MAC_hdr->length_in_bytes() + 1 - $tag_len;
  my @data = ($start_val..$len);
  for (@data) {$_ %= 100}
  $PDU->set_bytes(@data);

  # Return complete packet data
  $MAC_hdr->bytes().$PDU->bytes();
}

1;
