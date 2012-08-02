#!/bin/bash

# Execute this shell as a super user on your home directory

# 1. Tear down openflow protocol
# 2. Tear down datapath

killall ofprotocol
killall ofdatapath
