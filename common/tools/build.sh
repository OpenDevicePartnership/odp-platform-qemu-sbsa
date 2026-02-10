#!/usr/bin/env bash

export QEMU_ROOT=$WORKSPACE/common/tools/qemu

# Build QEMU for SBSA platform
cd $QEMU_ROOT
./configure --target-list=aarch64-softmmu --enable-gtk
ninja -C build

