#
# $Id$
# Author: Drew Mazurek
#
# Copyright (c) 2008, Stanford University
#

SCONE_PATH = ../../scone/sw
DRR_ROUTER_DIR = ${PWD}
INCLUDE_DIRS = -I../../scone/sw -I../lib/C
CFLAGS = -D_OQ_DRR_ $(INCLUDE_DIRS)
CC = gcc

default:
	@echo "This Makefile copies, patches, and builds the scone source"
	@echo "which must exist in $(SCONE_PATH)."
	@echo
	@echo "Usage:"
	@echo "% make scone"
	@echo
	@echo "The scone executable will be found in drr_scone/"

scone :
	if [[ -d $(SCONE_PATH)/.svn ]] ; then \
		svn export $(SCONE_PATH) drr_scone; \
	else \
		cp -r $(SCONE_PATH) drr_scone; \
	fi
	patch -p0 -d drr_scone < patches/or_cli.c.patch
	patch -p0 -d drr_scone < patches/or_data_types.h.patch
	patch -p0 -d drr_scone < patches/or_main.c.patch
	patch -p0 -d drr_scone < patches/Makefile.patch
	patch -p1 -d drr_scone < patches/left.html.patch
	cp src/* drr_scone
	$(MAKE) -C drr_scone

clean:
	rm -rf drr_scone
