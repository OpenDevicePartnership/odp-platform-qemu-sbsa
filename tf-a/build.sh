#!/usr/bin/env bash

# Setup environment variables
export TFA_ROOT=$WORKSPACE/tf-a/arm-trusted-firmware

cd $TFA_ROOT

# Hafnium build command for TFA
#make PLAT=qemu_sbsa \
#     SPD=spmd \
#     DEBUG=1 \
#     SMP=1 \
#     ENABLE_FEAT_HCX=1 
#     SPMD_SPM_AT_SEL2=1 \
#     CTX_INCLUDE_EL2_REGS=1 \
#     TRANSFER_LIST=1 \
#     HOB_LIST=1 \
#     BL32=$WORKSPACE/hafnium/out/reference/secure_qemu_aarch64_clang/hafnium.bin \
#      all fip

make PLAT=qemu_sbsa \
     BUILD_BASE=$WORKSPACE/Build/TFA/ \
     DEBUG=1 \
     all fip