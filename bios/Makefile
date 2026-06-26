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

all: patina-qemu

# ------------------------------------------------------------
# Build UEFI
# ------------------------------------------------------------
patina-qemu:
	@echo "=== Building BIOS ==="
	cd patina-qemu && \
	stuart_setup -c Platforms/QemuSbsaPkg/PlatformBuild.py && \
	stuart_update -c Platforms/QemuSbsaPkg/PlatformBuild.py && \
	stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py HAF_TFA_BUILD=TRUE MSSP_RUST_BIN_FILE=$(QEMU_RUST_BIN) MSSP_RUST_DTS_FILE=$(QEMU_RUST_DTS)

run:
	@echo "=== Running QEMU ==="
	cd patina-qemu && \
	stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py --flashrom

clean:
	@echo "=== Cleaning BIOS build artifacts ==="
	rm -rf Build

.PHONY : all patina-qemu run clean
