#!/usr/bin/env bash

# Check that WORKSPACE environmetn variable is set
if [ -z "${WORKSPACE}" ]; then
    echo "ERROR: WORKSPACE environment variable is not set."
    exit 1
fi

# Build QEMU
cd $WORKSPACE/common/tools
./build.sh

# Build Hafnium for SBSA QEMU
#cd $WORKSPACE/hafnium
#make PLATFORM=secure_qemu_aarch64

# Build TF-A images
cd $WORKSPACE/tf-a
./build.sh

# Build UEFI for SBSA QEMU
cd $WORKSPACE/uefi
./build.sh
