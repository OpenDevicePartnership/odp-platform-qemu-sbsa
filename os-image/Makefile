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

# ------------------------------------------------------------
# Generate qcow2 image from VHDX image
# ------------------------------------------------------------
qcow2: prebuilt/ValidationOS.vhdx
	mkdir -p build
	qemu-img convert -f vhdx -O qcow2 $< build/winvos.qcow2

# ------------------------------------------------------------
# Run QEMU with image to boot to OS
# ------------------------------------------------------------
run: qcow2
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

.PHONY : all os-image clean
