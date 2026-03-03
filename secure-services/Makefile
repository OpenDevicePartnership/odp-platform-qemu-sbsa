# ODP SBSA Build file
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0

WORKSPACE ?= $(CURDIR)/..

QEMU_RUST_BIN ?= $(WORKSPACE)/secure-services/odp-secure-services/target/aarch64-unknown-none/release/qemu-ec-sp
QEMU_RUST_DTS ?= $(WORKSPACE)/secure-services/odp-secure-services/platform/qemu-sp/linker/qemu-ec-sp.dts

secure-services: $(QEMU_RUST_BIN)

$(QEMU_RUST_BIN):$(WORKSPACE)/secure-services/odp-secure-services/platform/qemu-sp/Cargo.toml
	@echo "=== Building Secure Services ==="
	cargo objcopy --target=aarch64-unknown-none --release --manifest-path=$(WORKSPACE)/secure-services/odp-secure-services/platform/qemu-sp/Cargo.toml -- -O binary $(QEMU_RUST_BIN)

clean::
	cargo clean --manifest-path=$(WORKSPACE)/secure-services/odp-secure-services/platform/qemu-sp/Cargo.toml
