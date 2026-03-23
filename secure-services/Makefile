# ODP SBSA Build file
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0

QEMU_RUST_BIN := Build/qemu-ec-sp.bin
QEMU_RUST_DTS := Build/qemu-ec-sp.dts
EC_SECURE_DTS := platform/linker/qemu-ec-sp.dts

include ../Common.mk

all: $(QEMU_RUST_BIN) $(QEMU_RUST_DTS)

# ------------------------------------------------------------
# Build Secure EC Service
# ------------------------------------------------------------
$(QEMU_RUST_BIN): $(QEMU_RUST_DTS) builder-image
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/secure-services && \
		mkdir -p Build && \
		cd platform && \
		cargo objcopy --target=aarch64-unknown-none --release -- -O binary ../$(QEMU_RUST_BIN) \
	"

# ------------------------------------------------------------
# Copy DTS file to build directory
# ------------------------------------------------------------
$(QEMU_RUST_DTS): $(EC_SECURE_DTS)
	mkdir -p Build
	cp $(EC_SECURE_DTS) $(QEMU_RUST_DTS)

clean:
	rm -rf Build
ifeq ($(IN_DEVCONTAINER),1)
	cd platform && cargo clean
else
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/secure-services/platform && \
		cargo clean \
	"
endif

.PHONY: all clean