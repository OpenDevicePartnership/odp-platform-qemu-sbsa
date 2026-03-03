# ODP SBSA Build file
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0

QEMU_RUST_BIN ?= $(CURDIR)/Build/qemu-ec-sp.bin
QEMU_RUST_DTS ?= $(CURDIR)/Build/qemu-ec-sp.dts
EC_SECURE_DTS ?= $(CURDIR)/odp-secure-services/platform/qemu-sp/linker/qemu-ec-sp.dts

all: $(QEMU_RUST_BIN) $(QEMU_RUST_DTS)

# ------------------------------------------------------------
# Build Secure EC Service
# ------------------------------------------------------------
$(QEMU_RUST_BIN): $(QEMU_RUST_DTS)
	@echo "=== Building Secure Services ==="
	mkdir -p $(dir $(QEMU_RUST_BIN))
	cd odp-secure-services/platform/qemu-sp && \
	cargo objcopy --target=aarch64-unknown-none --release -- -O binary $(QEMU_RUST_BIN)

# ------------------------------------------------------------
# Copy DTS file to build directory
# ------------------------------------------------------------
$(QEMU_RUST_DTS): $(EC_SECURE_DTS)
	@echo "=== Copying DTS File ==="
	mkdir -p $(dir $(QEMU_RUST_DTS))
	cp $(EC_SECURE_DTS) $(QEMU_RUST_DTS)

clean:
	cd odp-secure-services/platform/qemu-sp && \
	cargo clean
	rm -f $(QEMU_RUST_BIN) $(QEMU_RUST_DTS)
