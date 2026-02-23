# ------------------------------------------------------------
# Environment setup
# ------------------------------------------------------------

WORKSPACE ?= $(CURDIR)/..
TFA_ROOT  := $(WORKSPACE)/tf-a/arm-trusted-firmware
PLAT_CONFIG := $(WORKSPACE)/tf-a/platform/config
SP_LAYOUT_FILE := $(PLAT_CONFIG)/sp_layout.json

DTB_DIR := $(WORKSPACE)/Build/tfa/qemu_sbsa/debug/fdts/
DTS_SRC := $(PLAT_CONFIG)/qemu-ec-sp.dts
DTB_OUT := $(DTB_DIR)/qemu-ec-sp.dtb

export TFA_ROOT
export SP_LAYOUT_FILE
export VIRTUALENV_HOME=/workspace/.venvs

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------

all: tfa-hafnium

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
	rsync -a --update $(WORKSPACE)/tf-a/platform/override/* $(TFA_ROOT)	
	$(MAKE) -C $(TFA_ROOT) -j \
		PLAT=qemu_sbsa \
 		BUILD_BASE=$(WORKSPACE)/Build/tfa \
		SPD=spmd \
		DEBUG=1 \
		LOG_LEVEL=50 \
		SMP=1 \
		SPMD_SPM_AT_SEL2=1 \
		TRANSFER_LIST=1 \
		HOB_LIST=1 \
		BL32=$(WORKSPACE)/spm/hafnium/out/reference/secure_qemu_aarch64_clang/hafnium.bin \
		QEMU_TB_FW_CONFIG_DTS=$(WORKSPACE)/tf-a/platform/config/qemu_sbsa_tb_fw_config.dts \
		QEMU_TOS_FW_CONFIG_DTS=$(WORKSPACE)/tf-a/platform/config/qemu_sbsa_spmc_manifest.dts \
		SP_LAYOUT_FILE=$(PLAT_CONFIG)/sp_layout.json \
		dtbs all fip


# ------------------------------------------------------------
# Optional: full FIP build (uncomment if needed)
# ------------------------------------------------------------
tfa:
	$(MAKE) -C $(TFA_ROOT) -j \
 		PLAT=qemu_sbsa \
 		BUILD_BASE=$(WORKSPACE)/Build/tfa \
 		DEBUG=1 \
 		all fip

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

clean:
	rm -rf $(WORKSPACE)/Build/tfa

.PHONY: all tfa-hafnium clean
