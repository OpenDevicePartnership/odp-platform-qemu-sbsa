# @file Makefile
#
# UEFI firmware build targets for the ODP QEMU SBSA Platform
#
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: Apache-2.0


include ../../Common.mk

all: patina-qemu-ec

# ------------------------------------------------------------
# Build UEFI without EC Support
# ------------------------------------------------------------
patina-qemu: builder-image
	$(call GROUP,Build UEFI (no EC))
	@$(DC_RUN) -w mod/uefi/patina-qemu -- stuart_setup -c Platforms/QemuSbsaPkg/PlatformBuild.py
	@$(DC_RUN) -w mod/uefi/patina-qemu -- stuart_update -c Platforms/QemuSbsaPkg/PlatformBuild.py
	@$(DC_RUN) -w mod/uefi/patina-qemu -- stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py
	$(call ENDGROUP)

# ------------------------------------------------------------
# Build UEFI with EC Support
# ------------------------------------------------------------
# REPO_ROOT_IN_DEVCONTAINER is referenced for stuart args (paths must be
# valid inside the container where stuart actually runs).
patina-qemu-ec: builder-image
	$(call GROUP,Build UEFI with EC)
	@$(DC_RUN) -w mod/uefi/patina-qemu -- stuart_setup -c Platforms/QemuSbsaPkg/PlatformBuild.py
	@$(DC_RUN) -w mod/uefi/patina-qemu -- stuart_update -c Platforms/QemuSbsaPkg/PlatformBuild.py
	@$(DC_RUN) -w mod/uefi/patina-qemu -- stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py \
		HAF_TFA_BUILD=TRUE \
		MSSP_RUST_BIN_FILE=$(REPO_ROOT_IN_DEVCONTAINER)/mod/secure-services/Build/qemu-ec-sp.bin \
		MSSP_RUST_DTS_FILE=$(REPO_ROOT_IN_DEVCONTAINER)/mod/secure-services/Build/qemu-ec-sp.dts \
		FEATURE_CONFIG_PATH=$(REPO_ROOT_IN_DEVCONTAINER)/mod/uefi/platform
	$(call ENDGROUP)

builder-shell: builder-image
	@$(DC_RUN) --shell

run: builder-image
	@$(DC_RUN) -w mod/uefi/patina-qemu -- \
		stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py --flashonly GDB_SERVER=5555 SERIAL_PORT=56789

clean:
	@echo "=== Cleaning UEFI build artifacts ==="
	cd $(REPO_ROOT_IN_HOST)/mod/uefi/patina-qemu && rm -rf Build Conf

.PHONY : all builder-image builder-shell patina-qemu patina-qemu-ec run clean
