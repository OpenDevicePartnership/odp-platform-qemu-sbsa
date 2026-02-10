# ------------------------------------------------------------
# Environment setup
# ------------------------------------------------------------

WORKSPACE ?= $(CURDIR)/..
TFA_ROOT  := $(WORKSPACE)/tf-a/arm-trusted-firmware
PLAT_CONFIG := $(WORKSPACE)/tf-a/platform/config
SP_LAYOUT_FILE := $(PLAT_CONFIG)/sp_layout.json

DTB_DIR := $(WORKSPACE)/Build/tfa/qemu_sbsa/debug/fdts/
DTS_SRC := $(PLAT_CONFIG)/qemu_sbsa_stmm_config.dts
DTB_OUT := $(DTB_DIR)/qemu_sbsa_stmm_config.dtb

export TFA_ROOT
export SP_LAYOUT_FILE

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------

all: tfa

# ------------------------------------------------------------
# Make DTB files as necessary
# ------------------------------------------------------------
$(DTB_OUT): $(DTS_SRC)
	@mkdir -p $(DTB_DIR)
	dtc -I dts -O dtb -o $@ $<

# ------------------------------------------------------------
# TF-A build target
# ------------------------------------------------------------
tfa-hafnium: $(DTB_OUT)
	@echo "Building TF-A in $(TFA_ROOT)"
	$(MAKE) -C $(TFA_ROOT) \
		PLAT=qemu_sbsa \
 		BUILD_BASE=$(WORKSPACE)/Build/tfa \
		SPD=spmd \
		DEBUG=1 \
		SMP=1 \
		ENABLE_FEAT_HCX=1 \
		SPMD_SPM_AT_SEL2=1 \
		CTX_INCLUDE_EL2_REGS=1 \
		TRANSFER_LIST=1 \
		HOB_LIST=1 \
		BL32=$(WORKSPACE)/hafnium/out/reference/secure_qemu_aarch64_clang/hafnium.bin \
		all fip

# ------------------------------------------------------------
# Optional: full FIP build (uncomment if needed)
# ------------------------------------------------------------
tfa: 
	$(MAKE) -C $(TFA_ROOT) \
 		PLAT=qemu_sbsa \
 		BUILD_BASE=$(WORKSPACE)/Build/tfa \
 		DEBUG=1 \
 		all fip

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

clean:
	rm -rf $(WORKSPACE)/Build/tfa

.PHONY: all tfa clean