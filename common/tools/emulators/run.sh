#!/usr/bin/env bash

WORKSPACE="$(realpath "$(dirname -- "${BASH_SOURCE[0]}")/../../..")"
IMAGE_ROOT=$WORKSPACE/Build/SbsaQemu

# Make sure QEMU dependencies are built
for f in SBSA_FLASH0.fd SBSA_FLASH1.fd; do
    path="$WORKSPACE/Build/SbsaQemu/DEBUG_GCC5/FV/$f"
    [ -f "$path" ] || { echo "ERROR: Missing $path"; exit 1; }
done

# Pad out the flash files to 256MB, which is the size expected by the QEMU machine definition
cp $WORKSPACE/Build/SbsaQemu/DEBUG_GCC5/FV/SBSA_FLASH[01].fd $WORKSPACE/Build/SbsaQemu
truncate -s 256M $WORKSPACE/Build/SbsaQemu/SBSA_FLASH[01].fd

# Run QEMU
qemu-system-aarch64 \
    -machine sbsa-ref \
    -cpu max,sve=off \
    -display none \
    -m 1G \
    -smp 4 \
    -drive if=pflash,format=raw,file=$IMAGE_ROOT/SBSA_FLASH0.fd \
    -drive if=pflash,format=raw,file=$IMAGE_ROOT/SBSA_FLASH1.fd \
    -serial stdio \
    -gdb tcp::1234

# Run QEMU for Secure partition
#qemu-system-aarch64 \
#    -net none \
#    -drive file=VirtualDrive.img,if=virtio \
#    -m 1G \
#    -machine sbsa-ref \
#    -cpu max \
#    -display none \
#    -smp 4 \
#    -global driver=cfi.pflash01,property=secure,value=on \
#    -drive if=pflash,format=raw,file=$IMAGE_ROOT/SBSA_FLASH0.fd \
#    -drive if=pflash,format=raw,file=$IMAGE_ROOT/SBSA_FLASH1.fd \
#    -device qemu-xhci,id=usb \
#    -device usb-tablet,id=input0,bus=usb.0,port=1 \
#    -device usb-kbd,id=input1,bus=usb.0,port=2 \
#    -smbios type=0,vendor="Project Mu",version="mu_tiano_platforms-v9.1.1-45-ga84c6009",date=02/17/2026,uefi=on \
#    -smbios type=1,manufacturer=Palindrome,product="QEMU SBSA",family=QEMU,version="10.1.50",serial=42-42-42-42 \
#    -smbios type=3,manufacturer=Palindrome,serial=42-42-42-42,asset=SBSA,sku=SBSA \
#    -serial stdio -serial file:secure.log -serial file:secure_mm.log
