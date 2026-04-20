# ODP SBSA Build file
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0

include Common.mk

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: mod-secure-services mod-uefi e2e-tests

# ------------------------------------------------------------
# Build Secure Services
# ------------------------------------------------------------
mod-secure-services:
	$(MAKE) -C mod-secure-services all

# Build secure services with test features and coverage profile (for e2e tests)
mod-secure-services-test:
	$(MAKE) -C mod-secure-services all CARGO_FEATURES=test-bypass-locality-check CARGO_PROFILE=coverage

# ------------------------------------------------------------
# Build UEFI with EC support by default
# Depends on mod-secure-services (mod-uefi consumes mod-secure-services artifacts)
# ------------------------------------------------------------
mod-uefi: mod-secure-services
	$(MAKE) -C mod-uefi patina-qemu-ec

# ------------------------------------------------------------
# Run QEMU with the built UEFI firmware
# ------------------------------------------------------------
run: mod-secure-services mod-uefi
	qemu-system-aarch64 \
		$(QEMU_COMMON_ARGS) \
		-drive if=pflash,format=raw,unit=0,file=$(BIOS_FV_DIR)/SECURE_FLASH0.fd \
		-drive if=pflash,format=raw,unit=1,file=$(BIOS_FV_DIR)/QEMU_EFI.fd,readonly=on \
		-serial mon:stdio \
		-display vnc=:1

run-in-devcontainer: mod-secure-services mod-uefi
	$(DOCKER_COMMAND_PREFIX) bash -lc "make run"

# ------------------------------------------------------------
# Run E2E tests against the secure partition
# ------------------------------------------------------------
# Build mod-secure-services-test first, then mod-uefi (skipping its normal
# mod-secure-services dependency to avoid overwriting the test binary).
e2e-test: mod-secure-services-test
	$(MAKE) -C mod-uefi patina-qemu-ec
	$(MAKE) -C e2e-tests test

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	$(MAKE) -C mod-secure-services clean
	$(MAKE) -C mod-uefi clean
	$(MAKE) -C e2e-tests clean

.PHONY: all mod-secure-services mod-secure-services-test mod-uefi run run-in-devcontainer e2e-test clean
