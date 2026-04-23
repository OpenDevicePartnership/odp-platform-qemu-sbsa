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
# `mod/ec` is a submodule, so its file list isn't valid until `submodule update --init`
# has run. Gate the binary rule on the submodule's manifest, and only enumerate sources
# once the manifest exists, so a deinit'd-then-reinit'd submodule properly invalidates
# the artifact.
EC_SUBMODULE_MANIFEST := mod/ec/rust-toolchain.toml
EC_SOURCES := $(if $(wildcard $(EC_SUBMODULE_MANIFEST)),$(shell find mod/ec -type f \( -name '*.rs' -o -name 'Cargo.toml' -o -name 'Cargo.lock' -o -name 'build.rs' -o -name 'memory.x' \)))
# EC_SERIAL_TIMEOUT bounds how long EC QEMU runs. EC has done its useful work
# (boot, announce PTY, exchange a few messages) well within 30s, after which it
# spins in tight async loops that starve SBSA of host CPU. Killing EC early lets
# SBSA reach the UEFI shell and self-terminate within SBSA_SERIAL_TIMEOUT.
EC_SERIAL_TIMEOUT  ?= 30
SBSA_SERIAL_TIMEOUT ?= 60

# Phony alias — lets callers say `make ec` while the real rule is on the artifact.
ec: $(EC_BINARY)

$(EC_SUBMODULE_MANIFEST):
	@echo "=== Initializing mod/ec submodule ==="
	git submodule update --init --recursive -- mod/ec

# Track the submodule's checked-out SHA via .git/modules/.../HEAD so a `git submodule
# update` to a new commit (which doesn't necessarily change any file under mod/ec at
# parse time) still invalidates the binary.
$(EC_BINARY): $(EC_SUBMODULE_MANIFEST) $(EC_SOURCES) .git/modules/mod/ec/HEAD | builder-image
	$(call GROUP,Build EC firmware)
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/$(EC_BUILD_DIR) && \
		cargo build --release --locked \
	"
	$(call ENDGROUP)
	@touch $@

# ------------------------------------------------------------
# Serial Communication Test
# ------------------------------------------------------------
# Launches EC QEMU with `-serial pty` (QEMU allocates a pseudo-tty
# and prints its path to stderr), parses the path, then launches
# SBSA QEMU with a `serial` chardev opening that PTY as serial1
# (SBSA_SECURE_UART @ 0x60030000).
# Verifies: PTY announced, EC booted, SBSA started without errors.
test-serial: $(EC_BINARY) uefi | builder-image
	@mkdir -p Build
	@echo "=== Running serial link test (EC timeout=$(EC_SERIAL_TIMEOUT)s, SBSA timeout=$(SBSA_SERIAL_TIMEOUT)s) ==="
	$(call GROUP,Serial link test)
	@$(DOCKER_COMMAND_PREFIX) bash -lc '\
		set -o pipefail; \
		cd $(REPO_ROOT) && \
		EC_ELF=$(EC_BINARY) && \
		mkdir -p Build Build/swtpm-state && \
		SWTPM_SOCK=Build/swtpm-state/swtpm-sock; \
		EC_PID=""; SWTPM_PID=""; \
		rm -f Build/ec-qemu-stderr.log Build/ec-qemu-stdout.log Build/ec-serial-output.log Build/sbsa-serial-output.log $$SWTPM_SOCK; \
		cleanup() { \
			[ -n "$$EC_PID" ] && kill -- -$$EC_PID 2>/dev/null; wait $$EC_PID 2>/dev/null; \
			[ -n "$$SWTPM_PID" ] && kill $$SWTPM_PID 2>/dev/null; wait $$SWTPM_PID 2>/dev/null; \
			true; \
		}; \
		trap cleanup EXIT; \
		swtpm socket \
			--tpmstate dir=Build/swtpm-state \
			--ctrl type=unixio,path=$$SWTPM_SOCK \
			--tpm2 --log level=20,file=Build/swtpm.log & \
		SWTPM_PID=$$!; \
		for i in $$(seq 1 50); do [ -S $$SWTPM_SOCK ] && break; sleep 0.1; done; \
		if [ ! -S $$SWTPM_SOCK ]; then echo "ERROR: swtpm socket not created"; exit 1; fi; \
		setsid bash -c "timeout $(EC_SERIAL_TIMEOUT) qemu-system-riscv32 \
			-machine virt \
			-bios none \
			-kernel $$EC_ELF \
			-semihosting \
			-display none \
			-serial pty \
			-monitor none \
			-no-reboot \
			2> Build/ec-qemu-stderr.log \
			| stdbuf -oL tee Build/ec-qemu-stdout.log \
			| defmt-print -e $$EC_ELF" \
			> Build/ec-serial-output.log 2>&1 & \
		EC_PID=$$!; \
		PTY=""; \
		for i in $$(seq 1 100); do \
			PTY=$$(grep -aoE "/dev/pts/[0-9]+" Build/ec-qemu-stdout.log Build/ec-qemu-stderr.log 2>/dev/null | grep -oE "/dev/pts/[0-9]+" | head -1) || true; \
			[ -n "$$PTY" ] && break; \
			sleep 0.1; \
		done; \
		if [ -z "$$PTY" ]; then \
			echo "ERROR: EC PTY path not reported within 10s"; \
			echo "--- EC QEMU stdout ---"; \
			cat Build/ec-qemu-stdout.log 2>/dev/null || echo "(empty)"; \
			echo "--- EC QEMU stderr ---"; \
			cat Build/ec-qemu-stderr.log 2>/dev/null || echo "(empty)"; \
			echo "--- End EC QEMU logs ---"; \
			exit 1; \
		fi; \
		echo "EC PTY: $$PTY — launching SBSA QEMU"; \
		SBSA_EXIT=0; \
		timeout $(SBSA_SERIAL_TIMEOUT) \
			qemu-system-aarch64 \
				$(QEMU_COMMON_ARGS) \
				-drive if=pflash,format=raw,unit=0,file=$(BIOS_FV_DIR)/SECURE_FLASH0.fd \
				-drive if=pflash,format=raw,unit=1,file=$(BIOS_FV_DIR)/QEMU_EFI.fd,readonly=on \
				-chardev socket,id=chrtpm,path=$$SWTPM_SOCK \
				-tpmdev emulator,id=tpm0,chardev=chrtpm \
				-chardev serial,id=ec-link,path=$$PTY \
				-serial file:Build/sbsa-serial-output.log \
				-serial chardev:ec-link \
				-drive file=fat:rw:test-serial-vdrive,format=raw,media=disk \
				-display none \
				-no-reboot \
		|| SBSA_EXIT=$$?; \
		exit $$SBSA_EXIT \
	'
	$(call ENDGROUP)
	@PASS=true; \
	if grep -q "Starting uart service" Build/ec-serial-output.log 2>/dev/null; then \
		echo "EC: boot successful (PTY serial backend)"; \
	else \
		echo "=== EC serial output ==="; \
		cat Build/ec-serial-output.log 2>/dev/null || echo "(empty)"; \
		echo "=== End EC serial output ==="; \
		echo "EC: boot FAILED — 'Starting uart service' not found"; \
		PASS=false; \
	fi; \
	if [ -s Build/sbsa-serial-output.log ]; then \
		echo "SBSA: produced serial output (PTY connected)"; \
	else \
		echo "SBSA: WARNING — no serial output captured (may be OK if boot is slow)"; \
	fi; \
	if $$PASS; then \
		echo "RESULT: SERIAL LINK TEST PASSED"; \
	else \
		echo "RESULT: SERIAL LINK TEST FAILED"; \
		exit 1; \
	fi

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

.PHONY: all secure-services secure-services-test uefi ec test-serial run run-in-devcontainer e2e-test clean
