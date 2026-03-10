# ODP SBSA Build file
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0


# ------------------------------------------------------------
# Workspace setup
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)
QEMU_RUST_BIN ?= $(WORKSPACE)/secure-services/Build/qemu-ec-sp.bin
QEMU_RUST_DTS ?= $(WORKSPACE)/secure-services/Build/qemu-ec-sp.dts
QEMU_RUST_OUTPUTS := $(QEMU_RUST_BIN) $(QEMU_RUST_DTS)

BIOS_FLASH0 := bios/patina-qemu/Build/QemuSbsaPkg/DEBUG_GCC5/FV/SECURE_FLASH0.fd
BIOS_EFI    := bios/patina-qemu/Build/QemuSbsaPkg/DEBUG_GCC5/FV/QEMU_EFI.fd
BIOS_OUTPUTS := $(BIOS_FLASH0) $(BIOS_EFI)

export QEMU_RUST_BIN
export QEMU_RUST_DTS

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: $(QEMU_RUST_OUTPUTS) $(BIOS_OUTPUTS)

# ------------------------------------------------------------
# Build Secure Services
# ------------------------------------------------------------
$(QEMU_RUST_OUTPUTS):
	$(MAKE) -C secure-services $(QEMU_RUST_BIN)

# ------------------------------------------------------------
# Build UEFI with EC support by default
# ------------------------------------------------------------
$(BIOS_OUTPUTS): $(QEMU_RUST_OUTPUTS)
	$(MAKE) -C bios patina-qemu-ec

# ------------------------------------------------------------
# Run QEMU with the built UEFI firmware
# ------------------------------------------------------------
run: $(QEMU_RUST_OUTPUTS) $(BIOS_OUTPUTS)
	qemu-system-aarch64 -semihosting -cpu max,sve=off,sme=off -smp 4 -machine sbsa-ref \
		-global driver=cfi.pflash01,property=secure,value=on -m 4G \
		-drive if=pflash,format=raw,unit=0,file=bios/patina-qemu/Build/QemuSbsaPkg/DEBUG_GCC5/FV/SECURE_FLASH0.fd \
		-drive if=pflash,format=raw,unit=1,file=bios/patina-qemu/Build/QemuSbsaPkg/DEBUG_GCC5/FV/QEMU_EFI.fd,readonly=on \
		-net none \
		-smbios type=0,vendor="Patina",version="v1.0.2",date="03/06/2026",uefi=on \
		-smbios type=1,manufacturer="OpenDevicePartnership",product="QEMU SBSA",family="QEMU",version="10.0.0",serial="42-42-42-42",uuid=99fb60e2-181c-413a-a3cf-0a5fea8d87b0 \
		-smbios type=3,manufacturer="OpenDevicePartnership",serial="42-42-42-42",asset="SBSA",sku="SBSA",version="" \
		-device qemu-xhci,id=usb -device usb-mouse,id=input0,bus=usb.0,port=1 \
		-device usb-kbd,id=input1,bus=usb.0,port=2 \
		-serial stdio \
		-display vnc=:1

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	$(MAKE) -C secure-services clean
	$(MAKE) -C bios clean
