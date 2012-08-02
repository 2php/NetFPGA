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
VLAN_ID_FOR_NF2C0=0x0000
VLAN_ID_FOR_NF2C1=0x0000
VLAN_ID_FOR_NF2C2=0x0000
VLAN_ID_FOR_NF2C3=0x0000

##############################################################
### Don't need to modify below

setreg (){
	REGNAME=$1;
	val=$2;
	echo "$REGNAME=$val"
	regwrite `grep  $REGNAME ../lib/C/reg_defines_vlan_tag_handler.h  |awk '{print $3}'`  $val;
	return 1;
}
getreg (){
	REGNAME=$1;
	echo $REGNAME;
	regread `grep  $REGNAME ../lib/C/reg_defines_vlan_tag_handler.h  |awk '{print $3}'`;
	return 1;
}

# Set up the forwarding ports
OUTPUT_PORTS_M0_REG_HEX=`grep HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG ../lib/C/reg_defines_vlan_tag_handler.h  |awk '{print $3}'`;

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

# Set up VLAN tags
setreg VLAN_ADDER_0_VLAN_TAG_REG $VLAN_ID_FOR_NF2C0;
setreg VLAN_ADDER_1_VLAN_TAG_REG $VLAN_ID_FOR_NF2C1;
setreg VLAN_ADDER_2_VLAN_TAG_REG $VLAN_ID_FOR_NF2C2;
setreg VLAN_ADDER_3_VLAN_TAG_REG $VLAN_ID_FOR_NF2C3;

