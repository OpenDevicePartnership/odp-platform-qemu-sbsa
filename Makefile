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

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: secure-services bios

# ------------------------------------------------------------
# Build Secure Services
# Makefile must define target for secure-services
# Makefile must export QEMU_RUST_BIN and QEMU_RUST_DTS
# ------------------------------------------------------------
include secure-services/Makefile

# ------------------------------------------------------------
# Build UEFI
# ------------------------------------------------------------
bios: secure-services
	@echo "=== Building BIOS ==="
	stuart_setup -c bios/Platforms/QemuSbsaPkg/PlatformBuild.py
	stuart_update -c bios/Platforms/QemuSbsaPkg/PlatformBuild.py
	stuart_build -c bios/Platforms/QemuSbsaPkg/PlatformBuild.py HAF_TFA_BUILD=TRUE MSSP_RUST_BIN_FILE=$(QEMU_RUST_BIN) MSSP_RUST_DTS_FILE=$(QEMU_RUST_DTS)

# ------------------------------------------------------------
# Run QEMU with the built BIOS
# ------------------------------------------------------------
run:
	@echo "=== Running QEMU ==="
	stuart_build -c bios/Platforms/QemuSbsaPkg/PlatformBuild.py --flashrom

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean::
	@echo "=== Cleaning all components ==="
	rm -rf $(WORKSPACE)/bios/Build

.PHONY : all secure-services bios run clean