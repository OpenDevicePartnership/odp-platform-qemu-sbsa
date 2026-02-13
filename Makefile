# ------------------------------------------------------------
# Workspace setup
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)

QEMU_DIR     := $(WORKSPACE)/common/tools/emulators
HAFNIUM_DIR  := $(WORKSPACE)/spm
TFA_DIR      := $(WORKSPACE)/tf-a
UEFI_DIR     := $(WORKSPACE)/uefi

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: qemu hafnium tfa uefi

# ------------------------------------------------------------
# Build QEMU
# ------------------------------------------------------------
qemu:
	@echo "=== Building QEMU ==="
	$(MAKE) -C $(QEMU_DIR)

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
	$(MAKE) -C $(QEMU_DIR) clean
	$(MAKE) -C $(HAFNIUM_DIR) clean
	$(MAKE) -C $(TFA_DIR) clean
	$(MAKE) -C $(UEFI_DIR) clean

.PHONY: all qemu hafnium tfa uefi clean