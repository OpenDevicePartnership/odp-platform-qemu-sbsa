# OS Image Makefile
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
OS_IMAGE_OUTPUT := build/winvos.qcow2
OS_IMAGE_INPUT := prebuilt/ValidationOS.vhdx

BIOS_FLASH0 := ../bios/patina-qemu/Build/QemuSbsaPkg/DEBUG_GCC5/FV/SECURE_FLASH0.fd
BIOS_EFI    := ../bios/patina-qemu/Build/QemuSbsaPkg/DEBUG_GCC5/FV/QEMU_EFI.fd
BIOS_OUTPUTS := $(BIOS_FLASH0) $(BIOS_EFI)

# ------------------------------------------------------------
# Throw error if the BIOS images are not present
# ------------------------------------------------------------
$(BIOS_OUTPUTS):
	@echo "Please build the BIOS images by running 'make all' in the root directory before building the OS image."
	@exit 1

# ------------------------------------------------------------
# Throw error if the input image is not present
# ------------------------------------------------------------
$(OS_IMAGE_INPUT):
	@echo "Please copy ValidationOS.vhdx to the prebuilt directory before building the OS image."
	@exit 1

# ------------------------------------------------------------
# Generate qcow2 image from VHDX image
# ------------------------------------------------------------
$(OS_IMAGE_OUTPUT): $(OS_IMAGE_INPUT)
	mkdir -p build
	qemu-img convert -f vhdx -O qcow2 $< $(OS_IMAGE_OUTPUT)

qcow2: $(OS_IMAGE_OUTPUT)

# ------------------------------------------------------------
# Run QEMU with image to boot to OS
# ------------------------------------------------------------
run: $(OS_IMAGE_OUTPUT) $(BIOS_OUTPUTS)
	qemu-system-aarch64 -semihosting -cpu max,sve=off,sme=off -smp 4 -machine sbsa-ref \
		-global driver=cfi.pflash01,property=secure,value=on -m 4G \
		-drive if=pflash,format=raw,unit=0,file=$(BIOS_FLASH0) \
		-drive if=pflash,format=raw,unit=1,file=$(BIOS_EFI),readonly=on \
		-net none \
		-smbios type=0,vendor="Patina",version="v1.0.2",date="03/06/2026",uefi=on \
		-smbios type=1,manufacturer="OpenDevicePartnership",product="QEMU SBSA",family="QEMU",version="10.0.0",serial="42-42-42-42",uuid=99fb60e2-181c-413a-a3cf-0a5fea8d87b0 \
		-smbios type=3,manufacturer="OpenDevicePartnership",serial="42-42-42-42",asset="SBSA",sku="SBSA",version="" \
		-device qemu-xhci,id=usb -device usb-mouse,id=input0,bus=usb.0,port=1 \
		-device usb-kbd,id=input1,bus=usb.0,port=2 \
		-serial stdio \
		-display vnc=:1 \
		-hda build/winvos.qcow2

# ------------------------------------------------------------
# Attach windbg -k com:ipport=5800,port=127.0.0.1 -v
# ------------------------------------------------------------
run_debug: qcow2
	qemu-system-aarch64 -semihosting -cpu max,sve=off,sme=off -smp 4 -machine sbsa-ref \
		-global driver=cfi.pflash01,property=secure,value=on -m 4G \
		-drive if=pflash,format=raw,unit=0,file=../bios/patina-qemu/Build/QemuSbsaPkg/DEBUG_GCC5/FV/SECURE_FLASH0.fd \
		-drive if=pflash,format=raw,unit=1,file=../bios/patina-qemu/Build/QemuSbsaPkg/DEBUG_GCC5/FV/QEMU_EFI.fd,readonly=on \
		-net none \
		-smbios type=0,vendor="Patina",version="v1.0.2",date="03/06/2026",uefi=on \
		-smbios type=1,manufacturer="OpenDevicePartnership",product="QEMU SBSA",family="QEMU",version="10.0.0",serial="42-42-42-42",uuid=99fb60e2-181c-413a-a3cf-0a5fea8d87b0 \
		-smbios type=3,manufacturer="OpenDevicePartnership",serial="42-42-42-42",asset="SBSA",sku="SBSA",version="" \
		-device qemu-xhci,id=usb -device usb-mouse,id=input0,bus=usb.0,port=1 \
		-device usb-kbd,id=input1,bus=usb.0,port=2 \
		-gdb tcp:127.0.0.1:5555,server,nowait \
		-serial tcp:127.0.0.1:5800,server,nowait \
		-display vnc=:1 \
		-hda build/winvos.qcow2

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	@echo "=== Cleaning OS image build artifacts ==="
	rm -rf build

