# E2E Tests for EC Secure Partition
#
# Builds Rust UEFI test applications, launches QEMU with the existing
# BIOS firmware, and executes tests against the secure partition.
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0

SHELL := /bin/bash

include ../Common.mk

# Build output paths
TARGET_DIR := target/aarch64-unknown-uefi/release
THERMAL_EFI := $(TARGET_DIR)/thermal.efi
TPM_EFI := $(TARGET_DIR)/tpm.efi
BIOS_BUILD_DIR := ../$(BIOS_FV_DIR)
SECURE_FLASH0 := $(BIOS_BUILD_DIR)/SECURE_FLASH0.fd
QEMU_EFI := $(BIOS_BUILD_DIR)/QEMU_EFI.fd

# Timeout for QEMU execution (seconds)
QEMU_TIMEOUT ?= 180

# Virtual drive directory for UEFI Shell to find test EFI binaries
VDRIVE_DIR := Build/vdrive

# swtpm state directory and socket path
SWTPM_DIR := Build/tpm
SWTPM_SOCK := $(SWTPM_DIR)/swtpm-sock

# Tee QEMU serial output to stdout (auto-enabled in CI)
ifeq ($(CI),true)
SERIAL_TEE ?= 1
else
SERIAL_TEE ?= 0
endif

# Serial output redirection: tee to stdout+file, or just file
ifeq ($(SERIAL_TEE),1)
SERIAL_FLAG := -serial stdio
SERIAL_REDIRECT := 2>&1 | tee Build/test-output.log
else
SERIAL_FLAG := -serial file:Build/test-output.log
SERIAL_REDIRECT :=
endif

# Coverage plugin
COVERAGE_PLUGIN := Build/libcoverage.so
COVERAGE_LOG := Build/coverage.log
SP_ELF := ../mod/secure-services/platform/target/aarch64-unknown-none/coverage/qemu-ec-sp

# All test EFI binaries
TEST_EFIS := $(THERMAL_EFI) $(TPM_EFI)

# ------------------------------------------------------------
# Build all test EFI binaries
# ------------------------------------------------------------
.PHONY: all
all: build

.PHONY: build
build: builder-image
	$(call GROUP,Build E2E test binaries)
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/e2e-tests && \
		cargo build --release \
	"
	$(call ENDGROUP)

# ------------------------------------------------------------
# Prepare the virtual FAT drive with test binaries + startup.nsh
# ------------------------------------------------------------
$(VDRIVE_DIR): build $(TEST_EFIS) startup.nsh
	rm -rf $(VDRIVE_DIR)
	mkdir -p $(VDRIVE_DIR)
	cp $(TEST_EFIS) $(VDRIVE_DIR)/
	cp startup.nsh $(VDRIVE_DIR)/startup.nsh

# ------------------------------------------------------------
# Run tests with timeout, capture output, report results
# ------------------------------------------------------------
# ------------------------------------------------------------
# Build the TCG coverage plugin (.so loaded by QEMU)
# ------------------------------------------------------------
$(COVERAGE_PLUGIN): builder-image
	$(call GROUP,Build coverage plugin)
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/e2e-tests && \
		make -C coverage-plugin BUILD_DIR=../Build \
	"
	$(call ENDGROUP)

.PHONY: test
test: $(VDRIVE_DIR) $(COVERAGE_PLUGIN)
	@mkdir -p Build
	@echo "=== Running E2E tests (timeout=$(QEMU_TIMEOUT)s) ==="
ifeq ($(SERIAL_TEE),1)
else
	@echo "    (serial output streaming to Build/test-output.log)"
endif
	$(call GROUP,QEMU serial output)
	@$(DOCKER_COMMAND_PREFIX) bash -lc '\
		set -o pipefail; \
		cd $(REPO_ROOT)/e2e-tests && \
		mkdir -p $(SWTPM_DIR) && \
		rm -f $(SWTPM_SOCK) || exit 1; \
		swtpm socket \
			--tpmstate dir=$(SWTPM_DIR) \
			--ctrl type=unixio,path=$(SWTPM_SOCK) \
			--tpm2 --log level=20,file=Build/swtpm.log & \
		SWTPM_PID=$$!; \
		for i in $$(seq 1 50); do [ -S $(SWTPM_SOCK) ] && break; sleep 0.1; done; \
		if [ ! -S $(SWTPM_SOCK) ]; then echo "ERROR: swtpm socket not created"; kill $$SWTPM_PID 2>/dev/null; exit 1; fi; \
		timeout $(QEMU_TIMEOUT) \
			qemu-system-aarch64 \
				$(QEMU_COMMON_ARGS) \
				-plugin file=$(COVERAGE_PLUGIN),outfile=$(COVERAGE_LOG) \
				-drive if=pflash,format=raw,unit=0,file=$(SECURE_FLASH0) \
				-drive if=pflash,format=raw,unit=1,file=$(QEMU_EFI),readonly=on \
				-chardev socket,id=chrtpm,path=$(SWTPM_SOCK) \
				-tpmdev emulator,id=tpm0,chardev=chrtpm \
				-drive file=fat:rw:$(VDRIVE_DIR),format=raw,media=disk \
				$(SERIAL_FLAG) \
				-display none \
				-no-reboot \
				$(SERIAL_REDIRECT); \
		QEMU_EXIT=$$?; \
		kill $$SWTPM_PID 2>/dev/null; wait $$SWTPM_PID 2>/dev/null; \
		exit $$QEMU_EXIT; \
	' & QEMU_PID=$$!; \
	trap "kill $$QEMU_PID 2>/dev/null; wait $$QEMU_PID 2>/dev/null; exit 130" INT TERM; \
	wait $$QEMU_PID; echo $$? > Build/qemu-exit-code
	$(call ENDGROUP)
	@EXIT_CODE=$$(cat Build/qemu-exit-code); \
	echo "=== Test output summary ==="; \
	grep -E "\[(PASS|FAIL)\]" Build/test-output.log || true; \
	echo ""; \
	if ! grep -q "EC Secure Partition E2E Tests" Build/test-output.log; then \
		echo "RESULT: TESTS NEVER RAN (banner not found in output)"; \
		exit 1; \
	elif grep -q "\[FAIL\]" Build/test-output.log; then \
		echo "RESULT: SOME TESTS FAILED"; \
		exit 1; \
	elif [ "$$EXIT_CODE" = "0" ] && grep -q '^--- Results: [0-9]\+ passed, 0 failed ---$$' Build/test-output.log; then \
		echo "RESULT: ALL TESTS PASSED"; \
		exit 0; \
	elif [ "$$EXIT_CODE" = "124" ]; then \
		echo "RESULT: TIMED OUT (no test output seen)"; \
		exit 1; \
	else \
		echo "RESULT: NO TEST OUTPUT FOUND (exit code $$EXIT_CODE)"; \
		exit 1; \
	fi

# ------------------------------------------------------------
# Generate coverage report from collected PCs
# ------------------------------------------------------------
.PHONY: coverage-report
coverage-report:
	$(call GROUP,Generate coverage report)
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/e2e-tests && \
		python3 scripts/pcs-to-lcov.py \
			--elf $(SP_ELF) \
			--input $(COVERAGE_LOG) \
			--output Build/coverage.info \
			--source-prefix odp-secure-services \
			--source-prefix odp-platform-qemu-sbsa && \
		genhtml Build/coverage.info \
			--ignore-errors source \
			--output-directory Build/coverage-html \
			--title 'EC Secure Partition Coverage' \
	"
	$(call ENDGROUP)

# ------------------------------------------------------------
# Clean build artifacts
# ------------------------------------------------------------
.PHONY: clean
clean:
	rm -rf Build
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/e2e-tests && \
		cargo clean && \
		make -C coverage-plugin clean \
	"
