#
# Makefile to setup the PTP software.
# Author: Peter Pawlowski
#

default:
	@echo "This Makefile is only responsible for setting up the SCONE-PTP source from SCONE (by applying a patch)."
	@echo "Type 'make install' to setup SCONE-PTP. Edit the Makefile to change the path to SCONE."
	@echo "Once installation is complete, cd to scone-ptp and type make."

SCONE_PATH=../../scone/sw
PTP_SW_DIR=${PWD}

install:
	if [[ -d $(SCONE_PATH)/.svn ]] ; then \
		svn export $(SCONE_PATH) scone-ptp; \
	else \
		cp -r $(SCONE_PATH) scone-ptp ;\
	fi
	patch -p0 -d scone-ptp/ < scone-ptp.patch

clean:
	@echo "Cowardly refusing to delete scone-ptp directory."
	@echo "If you want to start off fresh, rm -rf scone-ptp."
	@echo "WARNING: Make sure you have a backup or you have run \"make patch\" to make a patch."

.PHONY: patch
patch:
	cd scone-ptp; make clean; make clean-deps; rm -f reg_defines.h
	cd $(SCONE_PATH) ; \
	diff -x .svn -u -N -r ./ $(PTP_SW_DIR)/scone-ptp > $(PTP_SW_DIR)/scone-ptp.patch

