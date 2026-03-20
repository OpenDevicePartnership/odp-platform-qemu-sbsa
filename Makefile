# ODP SBSA Build file
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0

include Common.mk

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: secure-services bios

# Ensure bios builds after secure-services (bios consumes secure-services artifacts)
bios: secure-services

# ------------------------------------------------------------
# Build Secure Services
# ------------------------------------------------------------
secure-services:
	$(MAKE) -C secure-services all

# ------------------------------------------------------------
# Build UEFI with EC support by default
# ------------------------------------------------------------
bios:
	$(MAKE) -C bios patina-qemu-ec

# ------------------------------------------------------------
# Run QEMU with the built UEFI firmware
# ------------------------------------------------------------
run:
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
		-serial mon:stdio \
		-display vnc=:1

run-in-devcontainer: all
	$(DOCKER_COMMAND_PREFIX) bash -lc "make run"

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	$(MAKE) -C secure-services clean
	$(MAKE) -C bios clean

.PHONY: all secure-services bios run run-in-devcontainer clean
