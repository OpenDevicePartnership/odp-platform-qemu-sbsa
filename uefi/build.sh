#!/usr/bin/env bash

# Setup environment variables
export UEFI_ROOT=$WORKSPACE/uefi
export GCC5_AARCH64_PREFIX=/usr/bin/aarch64-linux-gnu-
export PACKAGES_PATH=$UEFI_ROOT/edk2:$UEFI_ROOT/edk2-platforms:$UEFI_ROOT/edk2-non-osi

# Apply necessary patches
cd $UEFI_ROOT/edk2-platforms
git apply --check $UEFI_ROOT/platform/SbsaQemuHardwareInfoLib.diff && git apply $UEFI_ROOT/platform/SbsaQemuHardwareInfoLib.diff

make -C $UEFI_ROOT/edk2/BaseTools
source $UEFI_ROOT/edk2/edksetup.sh

# Copy over the TF-A images to the EDK2 platform directory
cp $WORKSPACE/Build/TFA/qemu_sbsa/debug/bl1.bin $UEFI_ROOT/edk2-non-osi/Platform/Qemu/Sbsa/
cp $WORKSPACE/Build/TFA/qemu_sbsa/debug/fip.bin $UEFI_ROOT/edk2-non-osi/Platform/Qemu/Sbsa/

build -b DEBUG -a AARCH64 -t GCC5 -p $UEFI_ROOT/edk2-platforms/Platform/Qemu/SbsaQemu/SbsaQemu.dsc

# Post-build: Prepare output directory and flash files
cp $WORKSPACE/Build/SbsaQemu/DEBUG_GCC5/FV/SBSA_FLASH[01].fd $WORKSPACE/Build/SbsaQemu
truncate -s 256M $WORKSPACE/Build/SbsaQemu/SBSA_FLASH[01].fd
