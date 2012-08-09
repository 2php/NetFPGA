#!/bin/env python

from NFTest import *

phy2loop0 = ('../connections/conn', [])

nftest_init(sim_loop = [], hw_config = [phy2loop0])
nftest_start()

routerMAC = []
routerIP = []
for i in range(4):
    routerMAC.append("00:ca:fe:00:00:0%d"%(i+1))
    routerIP.append("192.168.%s.40"%i)

#num_broadcast = 10
num_broadcast = 1

# first packet
pkts = []
for i in range(num_broadcast):
    pkt = make_IP_pkt(src_MAC="aa:bb:cc:dd:ee:ff", dst_MAC=routerMAC[0],
                      src_IP="192.168.0.1", dst_IP="192.168.1.1", pkt_len=100)

    nftest_send_phy('nf2c0', pkt)
# for mac debugging
    nftest_expect_phy('nf2c1', pkt)
    if not isHW():
        nftest_expect_phy('nf2c2', pkt)
        nftest_expect_phy('nf2c3', pkt)



nftest_barrier()

num_broadcast = 1

# this should drop due to IP spoof
pkts = []
for i in range(num_broadcast):
    pkt = make_IP_pkt(src_MAC="aa:bb:cc:dd:ee:ff", dst_MAC=routerMAC[0],
                      src_IP="192.168.0.2", dst_IP="192.168.1.11", pkt_len=100)

    nftest_send_phy('nf2c0', pkt)
# don't expect
#    nftest_expect_phy('nf2c1', pkt)
#    if not isHW():
#        nftest_expect_phy('nf2c2', pkt)	# this should fail
#        nftest_expect_phy('nf2c3', pkt)	# this should fail

nftest_barrier()

# this should pass since no IP spoof
pkts = []
for i in range(num_broadcast):
    pkt = make_IP_pkt(src_MAC="aa:bb:cc:dd:de:ad", dst_MAC=routerMAC[0],
                      src_IP="192.168.0.1", dst_IP="192.168.1.1", pkt_len=100)
#
    nftest_send_phy('nf2c0', pkt)
    nftest_expect_phy('nf2c1', pkt)
    if not isHW():
        nftest_expect_phy('nf2c2', pkt)
        nftest_expect_phy('nf2c3', pkt)
nftest_barrier()

# this should drop due to MAC spoof
pkts = []
for i in range(num_broadcast):
    pkt = make_IP_pkt(src_MAC="aa:bb:cc:dd:ee:ff", dst_MAC=routerMAC[0],
                      src_IP="192.168.0.1", dst_IP="192.168.1.1", pkt_len=100)

    nftest_send_phy('nf2c0', pkt)
## for mac debugging
    #nftest_expect_phy('nf2c0', pkt)
    #if not isHW():
        #nftest_expect_phy('nf2c2', pkt)
        #nftest_expect_phy('nf2c3', pkt)

nftest_barrier()
nftest_finish()
