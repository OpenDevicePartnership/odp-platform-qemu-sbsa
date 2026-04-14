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
all: secure-services bios e2e-tests

# ------------------------------------------------------------
# Build Secure Services
# ------------------------------------------------------------
secure-services:
	$(MAKE) -C secure-services all

# Build secure services with test features and coverage profile (for e2e tests)
secure-services-test:
	$(MAKE) -C secure-services all CARGO_FEATURES=test-bypass-locality-check CARGO_PROFILE=coverage

# ------------------------------------------------------------
# Build UEFI with EC support by default
# Depends on secure-services (bios consumes secure-services artifacts)
# ------------------------------------------------------------
bios: secure-services
	$(MAKE) -C bios patina-qemu-ec

# ------------------------------------------------------------
# Run QEMU with the built UEFI firmware
# ------------------------------------------------------------
run: secure-services bios
	qemu-system-aarch64 \
		$(QEMU_COMMON_ARGS) \
		-drive if=pflash,format=raw,unit=0,file=$(BIOS_FV_DIR)/SECURE_FLASH0.fd \
		-drive if=pflash,format=raw,unit=1,file=$(BIOS_FV_DIR)/QEMU_EFI.fd,readonly=on \
		-serial mon:stdio \
		-display vnc=:1

run-in-devcontainer: secure-services bios
	$(DOCKER_COMMAND_PREFIX) bash -lc "make run"

# ------------------------------------------------------------
# Run E2E tests against the secure partition
# ------------------------------------------------------------
# Build secure-services-test first, then bios (skipping its normal
# secure-services dependency to avoid overwriting the test binary).
e2e-test: secure-services-test
	$(MAKE) -C bios patina-qemu-ec
	$(MAKE) -C e2e-tests test

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	$(MAKE) -C secure-services clean
	$(MAKE) -C bios clean
	$(MAKE) -C e2e-tests clean

.PHONY: all secure-services secure-services-test bios run run-in-devcontainer e2e-test clean
