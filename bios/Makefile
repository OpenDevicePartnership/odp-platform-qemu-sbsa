# ODP SBSA Build file
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0


include ../Common.mk

all: patina-qemu-ec

# ------------------------------------------------------------
# Build UEFI without EC Support
# ------------------------------------------------------------
patina-qemu: builder-image
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/bios/patina-qemu && \
		stuart_setup -c Platforms/QemuSbsaPkg/PlatformBuild.py && \
		stuart_update -c Platforms/QemuSbsaPkg/PlatformBuild.py && \
		stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py \
	"

# ------------------------------------------------------------
# Build UEFI with EC Support
# ------------------------------------------------------------
patina-qemu-ec: builder-image
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/bios/patina-qemu && \
		stuart_setup -c Platforms/QemuSbsaPkg/PlatformBuild.py && \
		stuart_update -c Platforms/QemuSbsaPkg/PlatformBuild.py && \
		stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py \
			HAF_TFA_BUILD=TRUE \
			MSSP_RUST_BIN_FILE=$(REPO_ROOT)/secure-services/Build/qemu-ec-sp.bin \
			MSSP_RUST_DTS_FILE=$(REPO_ROOT)/secure-services/Build/qemu-ec-sp.dts \
	"

builder-shell: builder-image
	$(DOCKER_COMMAND_PREFIX) bash

run: builder-image
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/bios/patina-qemu && \
		stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py --flashonly GDB_SERVER=5555 SERIAL_PORT=56789 \
	"

clean:
	@echo "=== Cleaning BIOS build artifacts ==="
	cd $(REPO_ROOT_IN_HOST)/bios/patina-qemu && rm -rf Build

.PHONY : all builder-image builder-shell patina-qemu patina-qemu-ec run clean
