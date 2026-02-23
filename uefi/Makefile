# ------------------------------------------------------------
# Environment setup
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)/..

UEFI_ROOT := $(WORKSPACE)/uefi
VENV := $(WORKSPACE)/.venv
PIP_FILE := $(UEFI_ROOT)/edk2/pip-requirements.txt
PIP_STAMP := $(UEFI_ROOT)/.pip_installed.stamp
UEFI_TFA_DIR := $(UEFI_ROOT)/edk2-non-osi/Platform/Qemu/Sbsa

TFA_ROOT := $(WORKSPACE)/tf-a
BL1_BIN := $(WORKSPACE)/Build/tfa/qemu_sbsa/debug/bl1.bin
FIP_BIN := $(WORKSPACE)/Build/tfa/qemu_sbsa/debug/fip.bin
TFA_FILES := $(BL1_BIN) $(FIP_BIN)


export UEFI_ROOT
export WORKSPACE := $(CURDIR)/..
export GCC5_AARCH64_PREFIX := /usr/bin/aarch64-linux-gnu-
export PACKAGES_PATH := $(UEFI_ROOT)/edk2:$(UEFI_ROOT)/edk2-platforms:$(UEFI_ROOT)/edk2-non-osi

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: edk2

# ------------------------------------------------------------
# Dependencies for TF-A output
# ------------------------------------------------------------
$(TFA_FILES):
	@echo "Building TF-A"
	$(MAKE) -C $(TFA_ROOT)

# ------------------------------------------------------------
# Depends for python
# ------------------------------------------------------------
pip-install: $(PIP_STAMP)

$(PIP_STAMP): $(PIP_FILE)
	@echo "Installing Python pip requirements..."
	python3 -m venv $(VENV)
	. $(VENV)/bin/activate && \
	    pip install --upgrade pip && \
	    pip install -r $(PIP_FILE)
	@touch $(PIP_STAMP)

# ------------------------------------------------------------
# 6. Source edksetup.sh
# ------------------------------------------------------------
basetools:
	@echo "Building BaseTools..."
	$(MAKE) -C $(UEFI_ROOT)/edk2/BaseTools

# ------------------------------------------------------------
# 7. Build UEFI firmware
# ------------------------------------------------------------
edk2: pip-install basetools $(TFA_FILES)
	@echo "Building UEFI SBSA QEMU firmware..."
	rsync -a --update $(WORKSPACE)/uefi/platform/override/* $(UEFI_ROOT)
	mkdir -p $(UEFI_TFA_DIR)
	cp $(BL1_BIN) $(UEFI_TFA_DIR)
	cp $(FIP_BIN) $(UEFI_TFA_DIR)
	@. $(VENV)/bin/activate && \
		cd $(UEFI_ROOT)/edk2 && \
		. ./edksetup.sh && \
		build -b DEBUG -a AARCH64 -t GCC5 \
			-D BUILD_DIR=$(WORKSPACE)/Build/UEFI \
			-p $(UEFI_ROOT)/edk2-platforms/Platform/Qemu/SbsaQemu/SbsaQemu.dsc

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------
clean:
	@echo "Cleaning UEFI build output..."
	rm -rf $(UEFI_ROOT)/Build

.PHONY: all pip-install edksetup edk2 clean
