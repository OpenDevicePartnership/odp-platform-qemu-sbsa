# odp-platform-qemu-sbsa
This repo contains all the necessary content for working on QEMU for SBSA (arm64) platform

## Quick Start Guide
This configuration has been tested on a windows running WSL Ubuntu 24.04 with Visual Studio Code.

After cloning the repository locally to WSL make sure from Visual Studio Code you have the WSL extension
installed to allow you to open code from terminal.

From the root folder run `code .` to start new VS code session. 
When prompted select to re-open in a container which will setup all the required tools and packages.

From VS code select `New Terminal` and run  `make all` from the root to rebuild all components.

Each sub folder has its own Makefile script to build each subcomponent.

## Folder Structure and Content

```
odp-platform-qemu-sbsa
  |- .github/           Github automation support (CI/CD)
  |- .devcontainer/     Devcontainer definitions
  |- bios/              ACPI, UEFI, TF-A, Hafnium and image creation
  |- ec/                EC MCU code
  |- secure-partition/  EC services and other secure partition code
  |- os-image           Scripts and steps for OS image generation
  |- common/            Tools, utilities and common code
  |- Makefile           Root makefile to make all components
  |- README.md          Quickstart file for each folder level
```
