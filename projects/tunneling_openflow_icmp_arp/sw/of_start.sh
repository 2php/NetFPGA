#!/bin/bash

### User dependent settings ###

## OpenFlow directory
OF_ROOT=/home/openflow/openflow

## Interfaces

###nf2c0
TUNIF0_ENABLE=0           # 0:Disable, 1:Enable
SRCIP0=111.111.111.111    # This interface's IP address
SRCMAC0=00:aa:bb:cc:dd:01 # This interface's MAC address
DSTIP0=111.111.111.111    # Destination IP address
DSTMAC0=11:11:11:11:11:11 # Your gate way MAC address
ENCAP_TAG0=0              # 32-bit tag value for the interface

###nf2c1
TUNIF1_ENABLE=0           # 0:Disable, 1:Enable
SRCIP1=111.111.111.111    # This interface's IP address
SRCMAC1=00:aa:bb:cc:dd:02 # This interface's MAC address
DSTIP1=111.111.111.111    # Destination IP address
DSTMAC1=11:11:11:11:11:11 # Your gate way MAC address
ENCAP_TAG1=0              # 32-bit tag value for the interface

###nf2c2
TUNIF2_ENABLE=0           # 0:Disable, 1:Enable
SRCIP2=111.111.111.111    # This interface's IP address
SRCMAC2=00:aa:bb:cc:dd:03 # This interface's MAC address
DSTIP2=111.111.111.111    # Destination IP address
DSTMAC2=11:11:11:11:11:11 # Your gate way MAC address
ENCAP_TAG2=0              # 32-bit tag value for the interface

###nf2c3
TUNIF3_ENABLE=0           # 0:Disable, 1:Enable
SRCIP3=111.111.111.111    # This interface's IP address
SRCMAC3=00:aa:bb:cc:dd:04 # This interface's MAC address
DSTIP3=111.111.111.111    # Destination IP address
DSTMAC3=11:11:11:11:11:11 # Your gate way MAC address
ENCAP_TAG3=0              # 32-bit tag value for the interface

### User dependent settings end here ###

# Other parameters
TUNIF0=nf2c0 
TUNIF1=nf2c1 
TUNIF2=nf2c2 
TUNIF3=nf2c3 

## useful func definitions;
dotdec2hex (){
      echo $1 | awk -F"." '{printf("0x%.2x%.2x%.2x%.2x",$1,$2,$3,$4);}'
}
macupper (){
      echo $1 | awk -F":" '{printf("0x%s%s",$1,$2);}'
}
maclower (){
      echo $1 | awk -F":" '{printf("0x%s%s%s%s",$3,$4,$5,$6);}'
}
setreg (){
	REGNAME=$1;
	val=$2;
	echo "$REGNAME=$val"
	regwrite `grep  $REGNAME $OF_ROOT/hw-lib/nf2/sw/reg_defines_tunneling_openflow_switch.h  |awk '{print $3}'`  $val;
	return 1;
}
getreg (){
	REGNAME=$1;
	echo $REGNAME;
	regread `grep  $REGNAME $OF_ROOT/hw-lib/nf2/sw/reg_defines_tunneling_openflow_switch.h  |awk '{print $3}'`;
	return 1;
}

## Internal Vars

h_SRCIP0=`dotdec2hex $SRCIP0`
h_DSTIP0=`dotdec2hex $DSTIP0`
U_SRCMAC0=`macupper $SRCMAC0`
L_SRCMAC0=`maclower $SRCMAC0`
U_DSTMAC0=`macupper $DSTMAC0`
L_DSTMAC0=`maclower $DSTMAC0`

h_SRCIP1=`dotdec2hex $SRCIP1`
h_DSTIP1=`dotdec2hex $DSTIP1`
U_SRCMAC1=`macupper $SRCMAC1`
L_SRCMAC1=`maclower $SRCMAC1`
U_DSTMAC1=`macupper $DSTMAC1`
L_DSTMAC1=`maclower $DSTMAC1`

h_SRCIP2=`dotdec2hex $SRCIP2`
h_DSTIP2=`dotdec2hex $DSTIP2`
U_SRCMAC2=`macupper $SRCMAC2`
L_SRCMAC2=`maclower $SRCMAC2`
U_DSTMAC2=`macupper $DSTMAC2`
L_DSTMAC2=`maclower $DSTMAC2`

h_SRCIP3=`dotdec2hex $SRCIP3`
h_DSTIP3=`dotdec2hex $DSTIP3`
U_SRCMAC3=`macupper $SRCMAC3`
L_SRCMAC3=`maclower $SRCMAC3`
U_DSTMAC3=`macupper $DSTMAC3`
L_DSTMAC3=`maclower $DSTMAC3`

## Download NetFPGA tunneling_openflow bitfile
nf_download $OF_ROOT/hw-lib/nf2/sw/tunneling_openflow_switch.bit

# Run OpenFlow datapth
$OF_ROOT/udatapath/ofdatapath punix:/var/run/test -i nf2c0,nf2c1,nf2c2,nf2c3 &

# Set up FPGA registers

# initialize DECAP_ENABLE register value
DECAP_ENB_0=0;
DECAP_ENB_1=0;
DECAP_ENB_2=0;
DECAP_ENB_3=0;

# Set up tunnel 0 (for nf2c0)
if [ $TUNIF0_ENABLE -eq 1 ]; then
    setreg ARP_REPLY_ETH_ADDR_PORT_0_LO_REG $L_SRCMAC0;
    setreg ARP_REPLY_ETH_ADDR_PORT_0_HI_REG $U_SRCMAC0;
    setreg ARP_REPLY_IP_ADDR_PORT_0_REG $h_SRCIP0;
    setreg ICMP_REPLY_ETH_ADDR_PORT_0_LO_REG $L_SRCMAC0;
    setreg ICMP_REPLY_ETH_ADDR_PORT_0_HI_REG $U_SRCMAC0;
    setreg ICMP_REPLY_IP_ADDR_PORT_0_REG $h_SRCIP0;
    setreg ENCAP_0_PORTS_REG 0x000f;
    setreg ENCAP_0_TAG_REG $ENCAP_TAG0;
    setreg ENCAP_0_SRC_IP_REG $h_SRCIP0;
    setreg ENCAP_0_DST_IP_REG $h_DSTIP0;
    setreg ENCAP_0_TTL_PROTO_REG 0xfff5;
    setreg ENCAP_0_TOS_REG 0x0;
    setreg ENCAP_0_SRC_MAC_HI_REG $U_SRCMAC0;
    setreg ENCAP_0_SRC_MAC_LO_REG $L_SRCMAC0;
    setreg ENCAP_0_DST_MAC_HI_REG $U_DSTMAC0;
    setreg ENCAP_0_DST_MAC_LO_REG $L_DSTMAC0;
    setreg ENCAP_0_ENABLE_REG 1;
    DECAP_ENB_0=1; #0x01
fi

# Set up tunnel 1 (for nf2c1)
if [ $TUNIF1_ENABLE -eq 1 ]; then
    setreg ARP_REPLY_ETH_ADDR_PORT_1_LO_REG $L_SRCMAC1;
    setreg ARP_REPLY_ETH_ADDR_PORT_1_HI_REG $U_SRCMAC1;
    setreg ARP_REPLY_IP_ADDR_PORT_1_REG $h_SRCIP1;
    setreg ICMP_REPLY_ETH_ADDR_PORT_1_LO_REG $L_SRCMAC1;
    setreg ICMP_REPLY_ETH_ADDR_PORT_1_HI_REG $U_SRCMAC1;
    setreg ICMP_REPLY_IP_ADDR_PORT_1_REG $h_SRCIP1;
    setreg ENCAP_1_PORTS_REG 0x000f;
    setreg ENCAP_1_TAG_REG $ENCAP_TAG1;
    setreg ENCAP_1_SRC_IP_REG $h_SRCIP1;
    setreg ENCAP_1_DST_IP_REG $h_DSTIP1;
    setreg ENCAP_1_TTL_PROTO_REG 0xfff5;
    setreg ENCAP_1_TOS_REG 0x0;
    setreg ENCAP_1_SRC_MAC_HI_REG $U_SRCMAC1;
    setreg ENCAP_1_SRC_MAC_LO_REG $L_SRCMAC1;
    setreg ENCAP_1_DST_MAC_HI_REG $U_DSTMAC1;
    setreg ENCAP_1_DST_MAC_LO_REG $L_DSTMAC1;
    setreg ENCAP_1_ENABLE_REG 1;
    DECAP_ENB_1=4; #0x04
fi

# Set up tunnel 2 (for nf2c2)
if [ $TUNIF2_ENABLE -eq 1 ]; then
    setreg ARP_REPLY_ETH_ADDR_PORT_2_LO_REG $L_SRCMAC2;
    setreg ARP_REPLY_ETH_ADDR_PORT_2_HI_REG $U_SRCMAC2;
    setreg ARP_REPLY_IP_ADDR_PORT_2_REG $h_SRCIP2;
    setreg ICMP_REPLY_ETH_ADDR_PORT_2_LO_REG $L_SRCMAC2;
    setreg ICMP_REPLY_ETH_ADDR_PORT_2_HI_REG $U_SRCMAC2;
    setreg ICMP_REPLY_IP_ADDR_PORT_2_REG $h_SRCIP2;
    setreg ENCAP_2_PORTS_REG 0x000f;
    setreg ENCAP_2_TAG_REG $ENCAP_TAG2;
    setreg ENCAP_2_SRC_IP_REG $h_SRCIP2;
    setreg ENCAP_2_DST_IP_REG $h_DSTIP2;
    setreg ENCAP_2_TTL_PROTO_REG 0xfff5;
    setreg ENCAP_2_TOS_REG 0x0;
    setreg ENCAP_2_SRC_MAC_HI_REG $U_SRCMAC2;
    setreg ENCAP_2_SRC_MAC_LO_REG $L_SRCMAC2;
    setreg ENCAP_2_DST_MAC_HI_REG $U_DSTMAC2;
    setreg ENCAP_2_DST_MAC_LO_REG $L_DSTMAC2;
    setreg ENCAP_2_ENABLE_REG 1;
    DECAP_ENB_2=16; #0x10
fi

# Set up tunnel 3 (for nf2c3)
if [ $TUNIF3_ENABLE -eq 1 ]; then
    setreg ARP_REPLY_ETH_ADDR_PORT_3_LO_REG $L_SRCMAC3;
    setreg ARP_REPLY_ETH_ADDR_PORT_3_HI_REG $U_SRCMAC3;
    setreg ARP_REPLY_IP_ADDR_PORT_3_REG $h_SRCIP3;
    setreg ICMP_REPLY_ETH_ADDR_PORT_3_LO_REG $L_SRCMAC3;
    setreg ICMP_REPLY_ETH_ADDR_PORT_3_HI_REG $U_SRCMAC3;
    setreg ICMP_REPLY_IP_ADDR_PORT_3_REG $h_SRCIP3;
    setreg ENCAP_3_PORTS_REG 0x000f;
    setreg ENCAP_3_TAG_REG $ENCAP_TAG3;
    setreg ENCAP_3_SRC_IP_REG $h_SRCIP3;
    setreg ENCAP_3_DST_IP_REG $h_DSTIP3;
    setreg ENCAP_3_TTL_PROTO_REG 0xfff5;
    setreg ENCAP_3_TOS_REG 0x0;
    setreg ENCAP_3_SRC_MAC_HI_REG $U_SRCMAC3;
    setreg ENCAP_3_SRC_MAC_LO_REG $L_SRCMAC3;
    setreg ENCAP_3_DST_MAC_HI_REG $U_DSTMAC3;
    setreg ENCAP_3_DST_MAC_LO_REG $L_DSTMAC3;
    setreg ENCAP_3_ENABLE_REG 1;
    DECAP_ENB_3=64; #0x40
fi

DECAP_ENB=`expr $DECAP_ENB_0 + $DECAP_ENB_1 + $DECAP_ENB_2 + $DECAP_ENB_3`

setreg ARP_REPLY_ENABLE_REG 1;
setreg ICMP_REPLY_ENABLE_REG 1;
setreg DECAP_IP_PROTO_REG  0xF5;
setreg DECAP_ENABLE_REG $DECAP_ENB;

# assign IPs and MAC addresses to our test ports
/sbin/ifconfig $TUNIF0 0.0.0.0
/sbin/ifconfig $TUNIF1 0.0.0.0
/sbin/ifconfig $TUNIF2 0.0.0.0
/sbin/ifconfig $TUNIF3 0.0.0.0

$OF_ROOT/secchan/ofprotocol punix:/var/run/test tcp:$1 --out-of-band

