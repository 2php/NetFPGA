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

##############################################################
### Don't need to modify below

########## <<<<<< Useful functions but not used in this script 
setreg (){
	REGNAME=$1;
	val=$2;
	echo "$REGNAME=$val"
	regwrite `grep  $REGNAME ../lib/C/reg_defines_hardwire_forwarding.h  |awk '{print $3}'`  $val;
	return 1;
}
getreg (){
	REGNAME=$1;
	echo $REGNAME;
	regread `grep  $REGNAME ../lib/C/reg_defines_hardwire_forwarding.h  |awk '{print $3}'`;
	return 1;
}
########## >>>>>>

# Set up the forwarding ports
OUTPUT_PORTS_M0_REG_HEX=`grep HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG ../lib/C/reg_defines_hardwire_forwarding.h  |awk '{print $3}'`;

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

