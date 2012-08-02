#!/usr/bin/perl -W

`/usr/local/sbin/cpci_reprogram.pl`;

`sleep 2`;

system("/usr/local/bin/nf2_download  /usr/local/NF2/bitfiles/rcp_router.bit") == 0 or die "Download of RCP router bitfile failed\n";
