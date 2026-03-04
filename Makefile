# ODP SBSA Build file
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0


# ------------------------------------------------------------
# Workspace setup
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)
QEMU_RUST_BIN ?= $(WORKSPACE)/secure-services/Build/qemu-ec-sp.bin
QEMU_RUST_DTS ?= $(WORKSPACE)/secure-services/Build/qemu-ec-sp.dts

export QEMU_RUST_BIN
export QEMU_RUST_DTS

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: secure-services bios

# ------------------------------------------------------------
# Build Secure Services
# ------------------------------------------------------------
secure-services: $(QEMU_RUST_BIN) $(QEMU_RUST_DTS)

$(QEMU_RUST_BIN):
	$(MAKE) -C secure-services $(QEMU_RUST_BIN)

$(QEMU_RUST_DTS):
	$(MAKE) -C secure-services $(QEMU_RUST_DTS)

# ------------------------------------------------------------
# Build UEFI
# ------------------------------------------------------------
bios: secure-services
	$(MAKE) -C bios patina-qemu

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	$(MAKE) -C secure-services clean
	$(MAKE) -C bios clean

.PHONY : all secure-services bios clean
