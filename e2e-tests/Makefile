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
BIOS_BUILD_DIR := ../bios/patina-qemu/Build/QemuSbsaPkg/DEBUG_GCC5/FV
SECURE_FLASH0 := $(BIOS_BUILD_DIR)/SECURE_FLASH0.fd
QEMU_EFI := $(BIOS_BUILD_DIR)/QEMU_EFI.fd

# Timeout for QEMU execution (seconds)
QEMU_TIMEOUT ?= 180

# Virtual drive directory for UEFI Shell to find test EFI binaries
VDRIVE_DIR := Build/vdrive

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

# All test EFI binaries
TEST_EFIS := $(THERMAL_EFI)

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
.PHONY: test
test: $(VDRIVE_DIR)
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
		timeout $(QEMU_TIMEOUT) \
			qemu-system-aarch64 -semihosting -cpu max,sve=off,sme=off -smp 4 -machine sbsa-ref \
				-global driver=cfi.pflash01,property=secure,value=on -m 4G \
				-drive if=pflash,format=raw,unit=0,file=$(SECURE_FLASH0) \
				-drive if=pflash,format=raw,unit=1,file=$(QEMU_EFI),readonly=on \
				-net none \
				-smbios type=0,vendor="Patina",version="v1.0.2",date="03/06/2026",uefi=on \
				-smbios type=1,manufacturer="OpenDevicePartnership",product="QEMU SBSA",family="QEMU",version="10.0.0",serial="42-42-42-42",uuid=99fb60e2-181c-413a-a3cf-0a5fea8d87b0 \
				-smbios type=3,manufacturer="OpenDevicePartnership",serial="42-42-42-42",asset="SBSA",sku="SBSA",version="" \
				-device qemu-xhci,id=usb -device usb-mouse,id=input0,bus=usb.0,port=1 \
				-device usb-kbd,id=input1,bus=usb.0,port=2 \
				-drive file=fat:rw:$(VDRIVE_DIR),format=raw,media=disk \
				$(SERIAL_FLAG) \
				-display none \
				-no-reboot \
				$(SERIAL_REDIRECT) \
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
# Clean build artifacts
# ------------------------------------------------------------
.PHONY: clean
clean:
	rm -rf Build
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/e2e-tests && \
		cargo clean \
	"
