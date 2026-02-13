# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)/../../..
QEMU_ROOT := $(WORKSPACE)/common/tools/emulators/qemu
CONFIG_FILE := $(QEMU_ROOT)/build/config-host.mak

export QEMU_ROOT

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: qemu

# ------------------------------------------------------------
# QEMU build logic
# ------------------------------------------------------------
qemu:
	@echo "Building QEMU in $(QEMU_ROOT)"
	@if [ ! -f "$(CONFIG_FILE)" ]; then \
		echo "QEMU not configured — running ./configure..."; \
		echo "PWD: $$(pwd)"; \
		cd $(QEMU_ROOT) && ./configure --target-list=aarch64-softmmu --enable-gtk; \
	else \
		echo "QEMU already configured — skipping configure step."; \
	fi
	@cd $(QEMU_ROOT) && ninja -C build

# ------------------------------------------------------------
# Clean target
# ------------------------------------------------------------
clean:
	@echo "Cleaning QEMU build directory..."
	@rm -rf $(QEMU_ROOT)/build

.PHONY: all qemu clean