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
all: secure-services ec uefi e2e-tests

# ------------------------------------------------------------
# Build Secure Services
# ------------------------------------------------------------
secure-services:
	$(MAKE) -C mod/secure-services all

# Build secure services with test features and coverage profile (for e2e tests)
secure-services-test:
	$(MAKE) -C mod/secure-services all CARGO_FEATURES=test-bypass-locality-check CARGO_PROFILE=coverage

# ------------------------------------------------------------
# Build UEFI with EC support by default
# Depends on mod-secure-services (mod-uefi consumes mod-secure-services artifacts)
# ------------------------------------------------------------
uefi: secure-services
	$(MAKE) -C mod/uefi patina-qemu-ec
	$(MAKE) -C mod/uefi patina-qemu-ec

# ------------------------------------------------------------
# Build EC firmware (RISC-V)
# ------------------------------------------------------------
EC_BUILD_DIR := mod/ec/platform/dev-qemu
EC_BINARY := $(EC_BUILD_DIR)/target/riscv32imac-unknown-none-elf/release/dev-qemu
EC_SOURCES := $(shell find mod/ec -type f \( -name '*.rs' -o -name 'Cargo.toml' -o -name 'Cargo.lock' -o -name 'build.rs' -o -name 'memory.x' \) 2>/dev/null)

# Phony alias — lets callers say `make ec` while the real rule is on the artifact.
ec: $(EC_BINARY)

$(EC_BINARY): $(EC_SOURCES) | builder-image
	$(call GROUP,Build EC firmware)
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/$(EC_BUILD_DIR) && \
		cargo build --release --locked \
	"
	$(call ENDGROUP)
	@touch $@

# ------------------------------------------------------------
# Run QEMU with the built UEFI firmware
# ------------------------------------------------------------
run: secure-services uefi
	qemu-system-aarch64 \
		$(QEMU_COMMON_ARGS) \
		-drive if=pflash,format=raw,unit=0,file=$(BIOS_FV_DIR)/SECURE_FLASH0.fd \
		-drive if=pflash,format=raw,unit=1,file=$(BIOS_FV_DIR)/QEMU_EFI.fd,readonly=on \
		-serial mon:stdio \
		-display vnc=:1

run-in-devcontainer: secure-services uefi
	$(DOCKER_COMMAND_PREFIX) bash -lc "make run"

# ------------------------------------------------------------
# Run E2E tests against the secure partition
# ------------------------------------------------------------
# Build secure-services-test first, then uefi (skipping its normal
# secure-services dependency to avoid overwriting the test binary).
e2e-test: secure-services-test
	$(MAKE) -C mod/uefi patina-qemu-ec
	$(MAKE) -C e2e-tests test

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	$(MAKE) -C mod/secure-services clean
	$(MAKE) -C mod/uefi clean
	$(MAKE) -C e2e-tests clean

.PHONY: all secure-services secure-services-test uefi ec run run-in-devcontainer e2e-test clean
