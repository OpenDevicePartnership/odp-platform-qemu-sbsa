# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)/..
HAFNIUM_ROOT := $(WORKSPACE)/spm/hafnium

export HAFNIUM_ROOT

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: hafnium

# ------------------------------------------------------------
# Hafnium build target
# ------------------------------------------------------------
hafnium:
	@echo "Building Hafnium for SBSA QEMU..."
	@echo "HAFNIUM_ROOT = $(HAFNIUM_ROOT)"
	$(MAKE) -C $(HAFNIUM_ROOT) PLATFORM=secure_qemu_aarch64

# ------------------------------------------------------------
# Clean target
# ------------------------------------------------------------
clean:
	@echo "Cleaning Hafnium build output..."
	$(MAKE) -C $(HAFNIUM_ROOT) clean

.PHONY: all hafnium clean