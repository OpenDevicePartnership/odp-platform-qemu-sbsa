# Windows Images

## Validation OS

The Makefile will look for ValidationOS.vhdx in this folder, convert it to qcow2 format and boot the QEMU with this image.

[Validation OS Windows 11](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/validation-os-overview?view=windows-11&viewFallbackFrom=windows-11_)

## Client OS

For booting Client OS on QEMU you will need a licensed copy of windows and we recommend booting windows under a VM and saving off the disk state, otherwise it will take a very long time to boot through OOBE.