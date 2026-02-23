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
odp-platform-<vendor>-<name>          Example: odp-platform-QEMU-SBSA
  |- .github/           Folder containing all github support (CI/CD)
  |- .devcontainer/     Folder with docker file content
  |- build/             Folder created by make
     |- uefi               output from the uefi build
     |- tf-a               output from the tf-a build
     |- (...)              output from component builds
  |- uefi/              Folder to compile the UEFI
     |- <core>            (SUBMODULE) Core infrastructure submodules
                          Example: tianocore/edk2/
     |- <silicon>         (SUBMODULE) Silicon vendor code submodules
     |- <vendor>          (SUBMODULE) Platform vendor code submodules
     |- tools/            Optional directory for tools that need to be compiled
        |- <tool_1>/          (SUBMODULE) Tool code needed to build component
        |- <tool_2>/          (SUBMODULE) Tool code needed to build component
     |- platform/         Platform config specific to UEFI
     |- build/            Optional folder for output from this component’s build
     |- Makefile          Makefile to build and produce the uefi binary
                          (use envvar to route artifacts to local or root build dir)
     |- readme.md         Misc housekeeping files
  |- tf-a/              Folder to compile the TF-A
     |- <core>            (SUBMODULE) Core infrastructure submodules
                          Example: trusted-firmware-a/
     |- <silicon>         (SUBMODULE) Silicon vendor code submodules
     |- <vendor>          (SUBMODULE) Platform vendor code submodules
     |- platform/         Platform config specific to TF-A
     |- tools/            Optional directory for tools that need to be compiled
     |- Makefile          Makefile to build and produce the TF-A binary
                          (use envvar to route artifacts to local or root build dir)
     |- readme.md         Misc housekeeping files
  |- spm                Folder to compile the secure partition manager
     |- <core>            (SUBMODULE) Core infrastructure
                          Example: trusted-firmware-a/
     |- <silicon>         (SUBMODULE) Code provided by silicon vendor
     |- <vendor>          (SUBMODULE) Code provided by platform vendor
     |- platform/         Platform config specific to Hafnium
     |- tools/            Optional directory for tools that need to be compiled
     |- build/            Optional folder for output from this component’s build
     |- Makefile          Builds and produces the binary
                          (use envvar to route artifacts to local or root build dir)
     |- readme.md         Misc housekeeping files
  |- ec                 Folder to compile the EC
     |- <core>            (SUBMODULE) Core infrastructure
     |- <silicon>         (SUBMODULE) Code provided by silicon vendor
     |- <vendor>          (SUBMODULE) Code provided by platform vendor
     |- tools/            Optional directory for tools that need to be compiled
     |- platform/         Platform config specific to the EC
     |- build/            Optional folder for output from this component’s build
     |- Makefile          Builds and produces the binary
                          (use envvar to route artifacts to local or root build dir)
     |- readme.md         Misc housekeeping files
  |- acpi               Folder to compile the ACPI
     |- <common>          (SUBMODULE/Nuget) Is there common code we can use?
     |- DSDT/             Platform code for the DSDT table
     |- <table(n)>/       Platform code for the (n) table
     |- tools/            Optional directory for tools that need to be compiled
     |- build/            Optional folder for output from this component’s build
     |- Makefile          Builds and produces the binary
                          (use envvar to route artifacts to local or root build dir)
     |- readme.md         Misc housekeeping files
  |- secure-partition   Folder to create the secure partition binary
     |- <item 1>          (SUBMODULE/Nuget) Example: EC Service binary
     |- <item 2>          (SUBMODULE/Nuget) Example: Version Manifest builder
     |- tools/            Optional directory for tools that need to be compiled
     |- platform/         Platform config specific to the secure partition
     |- build/            Optional folder for output from this component’s build
     |- Makefile          Builds and produces the binary
                          (use envvar to route artifacts to local or root build dir)
     |- readme.md         Misc housekeeping files
  |- os-image           Folder to create the OS image
     |- <item (n)>        (SUBMODULE/Nuget) Pre-existing feed if needed
     |- tools/            Optional directory for tools that need to be compiled
     |- platform/         Platform config specific to the OS image
     |- os_drop/          Place holder for install.wim and OS content from EEAP
     |- drivers/          Platform specific drivers
     |- build/            Optional folder for output from this component’s build
     |- Makefile          Injects drivers into install.wim to create disk image
                          (use envvar to route artifacts to local or root build dir)
     |- readme.md         Misc housekeeping files
  |- common/            Folder to hold code common to all components
     |- platform/         Do we want a single config for all components? Device Tree?
     |- odp-sdk/          (SUBMODULE) Common ODP SDK code
     |- tools/            Optional directory for tools that need to be compiled
        |- <tool_1>/          (SUBMODULE) Tool code needed to build component
        |- <tool_2>/          (SUBMODULE) Tool code needed to build component
     |- container.json    Container config for CI/CD and build.sh
     |- build/            Optional folder for output from any build time processing
     |- Makefile          Build time processing of this folder
                          (use envvar to route artifacts to local or root build dir)
     |- readme.md         Misc housekeeping files
  |- Makefile           Executes each component build.sh then the final binary
  |- readme.md          Misc housekeeping files
```
