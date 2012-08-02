#
# $Id: Makefile 3739 2008-05-15 21:04:00Z grg $
#

CFLAGS = -g -I ../../../lib/C/common
CC = gcc
LDFLAGS = -lncurses

all : regdump 

regdump : regdump.o $(NF2_ROOT)/lib/C/common/nf2util.o $(NF2_ROOT)/lib/C/common/reg_defines.h

clean :
	rm -f regdump *.o

install:

.PHONY: all clean install
