# OS Image Makefile
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0

include ../Common.mk

# ------------------------------------------------------------
# Workspace setup
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)
OS_IMAGE_OUTPUT := build/winvos.qcow2
OS_IMAGE_INPUT := prebuilt/ValidationOS.vhdx

BIOS_FLASH0 := ../../$(BIOS_FV_DIR)/SECURE_FLASH0.fd
BIOS_EFI    := ../../$(BIOS_FV_DIR)/QEMU_EFI.fd
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
	qemu-system-aarch64 \
		$(QEMU_COMMON_ARGS) \
		-drive if=pflash,format=raw,unit=0,file=$(BIOS_FLASH0) \
		-drive if=pflash,format=raw,unit=1,file=$(BIOS_EFI),readonly=on \
		-serial stdio \
		-display vnc=:1 \
		-hda build/winvos.qcow2

# ------------------------------------------------------------
# Attach windbg -k com:ipport=5800,port=127.0.0.1 -v
# ------------------------------------------------------------
run_debug: qcow2 $(BIOS_OUTPUTS)
	qemu-system-aarch64 \
		$(QEMU_COMMON_ARGS) \
		-drive if=pflash,format=raw,unit=0,file=$(BIOS_FLASH0) \
		-drive if=pflash,format=raw,unit=1,file=$(BIOS_EFI),readonly=on \
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

