#------------------------------------------------------------------------------
# File: Makefile
# Date: July, 2008
# Author: Sara Bolouki
#
# Note: Make file of RCP router
#
# -----------------------------------------------------------------------------

CC=cc
CFLAGS=  -O3 
OBJECTS= sr_router.o nf2util.o 
LIBS = -lm

# --- targets
all:    sr_router
sr_router:   $(OBJECTS)
	$(CC)  -o sr_router $(OBJECTS) $(LIBS)
sr_router.o: reg_defines.h sr_router.c 
	$(CC) -c sr_router.c
nf2util.o: nf2util.h nf2util.c 
	$(CC) -c nf2util.c

# --- remove binary and executable files
clean:
	rm -f sr_router $(OBJECTS)

