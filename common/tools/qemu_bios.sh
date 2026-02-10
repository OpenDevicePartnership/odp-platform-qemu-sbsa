#!/usr/bin/env bash

export QEMU_ROOT=$WORKSPACE/common/tools/qemu
export IMAGE_ROOT=$WORKSPACE/Build/SbsaQemu


# Run QEMU
$QEMU_ROOT/build/qemu-system-aarch64 -machine sbsa-ref -cpu max -m 1G -drive if=pflash,format=raw,file=$IMAGE_ROOT/SBSA_FLASH0.fd -drive if=pflash,format=raw,file=$IMAGE_ROOT/SBSA_FLASH1.fd -serial stdio