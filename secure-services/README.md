# secure-services
This repo contains secure partition code to compile and generate binaries to run in S-EL2 under Hafnium

## Quick Start Guide
To build the EC secure partition for QEMU from this folder run 

`make secure-services`

By default release version is built and output binary can be found at

`odp-secure-services/target/aarch64-unknown-none/release/qemu-ec-sp`

The DTS and linker addresses must match those defined by TF-A and hafnium images. You can find the addresses listed under the following files.

```
odp-secure-services/platform/qemu-sp/linker/qemu-ec-sp.dts
odp-secure-services/platform/qemu-sp/linker/qemu.ld
```

The GUID's size and offset must match those in the sp_layout.json generated from PlatformBuild.py. The addresses for the secure partitions in the hafnium manifest can be found in the tfa_patches folder under:

`bios/Platforms/QemuSbsaPkg/tfa_patches`

For further details about the QEMU EC partition code refer to the README.md under

`bios/Platforms/QemuSbsaPkg/tfa_patches`