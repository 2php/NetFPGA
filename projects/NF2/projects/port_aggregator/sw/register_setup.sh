#!/bin/bash

### Specify output ports for each INPUT port.
### Least 8 bits are valid as output ports.
### bit0: nf2c0, bit2: nf2c1, bit4: nf2c2, bit6: nf2c3
### Bit1,3,5,7 are CPU ports and vlan tagging are not supported
### for those ports.
### ex) If you want to send out to nf2c3, set 0x40.
OUTPUT_PORTS_FOR_NF2C0=0x04
OUTPUT_PORTS_FOR_NF2C1=0x01
OUTPUT_PORTS_FOR_NF2C2=0x40
OUTPUT_PORTS_FOR_NF2C3=0x10
### You can also setup the values for CPU ports.
OUTPUT_PORTS_FOR_CPU0=0x00
OUTPUT_PORTS_FOR_CPU1=0x00
OUTPUT_PORTS_FOR_CPU2=0x00
OUTPUT_PORTS_FOR_CPU3=0x00

### Specify VLAN tags for each OUTPUT port.
### The value should be a 16-bit value conbined VLAN priority
### bits and VLAN ID.
###  Bits 15-13:VLAN priority
###  Bit 12    :should be 0
###  bits 11-0 :VLAN ID
### There are two special values:
###  0x0000 (default value when reset): pass through
###  0xFFFF: VLAN remove.
###          If set, Vlan tag and VLAN ethertype of '0x8100'
###          will be removed.
VLAN_ID_FOR_NF2C0_OUT=0x0000
VLAN_ID_FOR_NF2C1_OUT=0x0000
VLAN_ID_FOR_NF2C2_OUT=0x0000
VLAN_ID_FOR_NF2C3_OUT=0x0000

### Specify acceptable VLAN tags for each INPUT port.
### The value should be a 16-bit value but VLAN priority
### bits are ignored.
### Unless the VLAN ID of an incoming packets is as same as
### the set value below, the packet will be discarded.
###  Bits 15-13:ignored
###  Bit 12    :ignored
###  bits 11-0 :VLAN ID
VLAN_ID_FOR_NF2C0_IN=0x0000
VLAN_ID_FOR_NF2C1_IN=0x0000
VLAN_ID_FOR_NF2C2_IN=0x0000
VLAN_ID_FOR_NF2C3_IN=0x0000

### Specify output port for sending out packets.
### All the packets which are supposed to come out of 
### nf2c0-nf2c3 will be aggregated and come out of
### the specified port here.
### Bits 15-2:ignored
### Bits 1-0: port
###   nf2c0:0, nf2c1:1, nf2c2:2, nf2c3:3
OUTPORT=0x0

##############################################################
### Don't need to modify below

setreg (){
	REGNAME=$1;
	val=$2;
	echo "$REGNAME=$val"
	regwrite `grep  $REGNAME ../lib/C/reg_defines_port_aggregator.h  |awk '{print $3}'`  $val;
	return 1;
}
getreg (){
	REGNAME=$1;
	echo $REGNAME;
	regread `grep  $REGNAME ../lib/C/reg_defines_port_aggregator.h  |awk '{print $3}'`;
	return 1;
}

# Set up the forwarding ports
OUTPUT_PORTS_M0_REG_HEX=`grep HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG ../lib/C/reg_defines_port_aggregator.h  |awk '{print $3}'`;

OUTPUT_PORTS_M0_REG=$(($OUTPUT_PORTS_M0_REG_HEX))
OUTPUT_PORTS_C0_REG=$(($OUTPUT_PORTS_M0_REG+4));
OUTPUT_PORTS_M1_REG=$(($OUTPUT_PORTS_C0_REG+4));
OUTPUT_PORTS_C1_REG=$(($OUTPUT_PORTS_M1_REG+4));
OUTPUT_PORTS_M2_REG=$(($OUTPUT_PORTS_C1_REG+4));
OUTPUT_PORTS_C2_REG=$(($OUTPUT_PORTS_M2_REG+4));
OUTPUT_PORTS_M3_REG=$(($OUTPUT_PORTS_C2_REG+4));
OUTPUT_PORTS_C3_REG=$(($OUTPUT_PORTS_M3_REG+4));

regwrite $OUTPUT_PORTS_M0_REG $OUTPUT_PORTS_FOR_NF2C0;
regwrite $OUTPUT_PORTS_C0_REG $OUTPUT_PORTS_FOR_CPU0;
regwrite $OUTPUT_PORTS_M1_REG $OUTPUT_PORTS_FOR_NF2C1;
regwrite $OUTPUT_PORTS_C1_REG $OUTPUT_PORTS_FOR_CPU1;
regwrite $OUTPUT_PORTS_M2_REG $OUTPUT_PORTS_FOR_NF2C2;
regwrite $OUTPUT_PORTS_C2_REG $OUTPUT_PORTS_FOR_CPU2;
regwrite $OUTPUT_PORTS_M3_REG $OUTPUT_PORTS_FOR_NF2C3;
regwrite $OUTPUT_PORTS_C3_REG $OUTPUT_PORTS_FOR_CPU3;

# Set up VLAN tags for output
setreg VLAN_ADDER_0_VLAN_TAG_REG $VLAN_ID_FOR_NF2C0_OUT;
setreg VLAN_ADDER_1_VLAN_TAG_REG $VLAN_ID_FOR_NF2C1_OUT;
setreg VLAN_ADDER_2_VLAN_TAG_REG $VLAN_ID_FOR_NF2C2_OUT;
setreg VLAN_ADDER_3_VLAN_TAG_REG $VLAN_ID_FOR_NF2C3_OUT;

# Set up VLAN tags for input
setreg VLAN_REMOVER_INPORT_0_VLAN_TAG_REG $VLAN_ID_FOR_NF2C0_IN;
setreg VLAN_REMOVER_INPORT_1_VLAN_TAG_REG $VLAN_ID_FOR_NF2C1_IN;
setreg VLAN_REMOVER_INPORT_2_VLAN_TAG_REG $VLAN_ID_FOR_NF2C2_IN;
setreg VLAN_REMOVER_INPORT_3_VLAN_TAG_REG $VLAN_ID_FOR_NF2C3_IN;

# Set up aggregation port
setreg OUT_AGGR_OUTPORT_REG $OUTPORT;
