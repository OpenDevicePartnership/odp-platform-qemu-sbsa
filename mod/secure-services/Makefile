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

include ../../Common.mk

# Optional cargo features (e.g. test-bypass-locality-check for e2e tests)
CARGO_FEATURES ?=
# Cargo profile to build with (release or coverage)
CARGO_PROFILE ?= release

all: $(QEMU_RUST_BIN) $(QEMU_RUST_DTS)

# ------------------------------------------------------------
# Build Secure EC Service
# ------------------------------------------------------------
$(QEMU_RUST_BIN): $(QEMU_RUST_DTS) builder-image
	$(call GROUP,Build Secure EC Service)
	$(DOCKER_COMMAND_PREFIX) bash -lc " \
		cd $(REPO_ROOT)/mod/secure-services && \
		mkdir -p Build && \
		cd platform && \
		cargo objcopy --target=aarch64-unknown-none --profile $(CARGO_PROFILE) $(if $(CARGO_FEATURES),--features=$(CARGO_FEATURES),) -- -O binary ../$(QEMU_RUST_BIN) \
	"
	$(call ENDGROUP)

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
		cd $(REPO_ROOT)/mod/secure-services/platform && \
		cargo clean \
	"
endif

.PHONY: all clean
