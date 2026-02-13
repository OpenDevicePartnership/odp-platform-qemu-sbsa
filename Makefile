# ------------------------------------------------------------
# Workspace setup
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)

HAFNIUM_DIR  := $(WORKSPACE)/spm
TFA_DIR      := $(WORKSPACE)/tf-a
UEFI_DIR     := $(WORKSPACE)/uefi

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: hafnium tfa uefi

# ------------------------------------------------------------
# Build Hafnium
# ------------------------------------------------------------
hafnium:
	@echo "=== Building Hafnium ==="
	$(MAKE) -C $(HAFNIUM_DIR)

# ------------------------------------------------------------
# Build TF-A
# ------------------------------------------------------------
tfa:
	@echo "=== Building TF-A ==="
	$(MAKE) -C $(TFA_DIR)

# ------------------------------------------------------------
# Build UEFI
# ------------------------------------------------------------
uefi:
	@echo "=== Building UEFI ==="
	$(MAKE) -C $(UEFI_DIR)

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	@echo "=== Cleaning all components ==="
	$(MAKE) -C $(HAFNIUM_DIR) clean
	$(MAKE) -C $(TFA_DIR) clean
	$(MAKE) -C $(UEFI_DIR) clean

.PHONY: all hafnium tfa uefi clean