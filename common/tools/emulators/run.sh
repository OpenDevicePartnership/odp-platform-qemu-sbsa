#!/usr/bin/env bash

WORKSPACE=${WORKSPACE:-"$(pwd)/../../.."}
export QEMU_ROOT=$WORKSPACE/common/tools/emulators/qemu
export IMAGE_ROOT=$WORKSPACE/Build/SbsaQemu

# Make sure QEMU dependencies are built
for f in SBSA_FLASH0.fd SBSA_FLASH1.fd; do
    path="$WORKSPACE/Build/SbsaQemu/DEBUG_GCC5/FV/$f"
    [ -f "$path" ] || { echo "ERROR: Missing $path"; exit 1; }
done

# Pad out the flash files to 256MB, which is the size expected by the QEMU machine definition
cp $WORKSPACE/Build/SbsaQemu/DEBUG_GCC5/FV/SBSA_FLASH[01].fd $WORKSPACE/Build/SbsaQemu
truncate -s 256M $WORKSPACE/Build/SbsaQemu/SBSA_FLASH[01].fd

# Run QEMU
$QEMU_ROOT/build/qemu-system-aarch64 -machine sbsa-ref -cpu max -m 1G -drive if=pflash,format=raw,file=$IMAGE_ROOT/SBSA_FLASH0.fd -drive if=pflash,format=raw,file=$IMAGE_ROOT/SBSA_FLASH1.fd -serial stdio