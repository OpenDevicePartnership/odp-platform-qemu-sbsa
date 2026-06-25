# UEFI Platform Overlay

This directory holds the platform overlay that is prepended to the patina-qemu
edk2 `PACKAGES_PATH`. Files here can override or extend the platform build
without editing the `mod/uefi/patina-qemu` workspace.

## ACPI table rebuild helper

Use `build_acpi_tables.sh` to rebuild
`QemuArmVirtPkg/AcpiTables/AcpiTables.inf` and patch the resulting freeform FFS
into an existing `QEMU_EFI.fd` image.

The script:

- uses `QemuArmVirtPkg.dsc` from `patina-qemu`, and if the overlay copy is
  absent it stages a temporary replacement from that upstream file,
- builds only `QemuArmVirtPkg/AcpiTables/AcpiTables.inf`,
- finds the generated `7E374E25-8E01-4FEE-87F2-390C23C606CD` freeform FFS, and
- patches the selected firmware image in place by replacing that FFS inside the
  `FvMain` firmware volume, falling back to `add` when the FFS is not already
  present.

The script assumes `stuart_setup` and `stuart_update` have already been run.

Examples:

```sh
mod/uefi/platform/build_acpi_tables.sh
mod/uefi/platform/build_acpi_tables.sh --firmware /tmp/QEMU_EFI.fd
```

By default the input firmware is:

```sh
mod/uefi/patina-qemu/Build/QemuArmVirtPkg/DEBUG_CLANGPDB/FV/QEMU_EFI.fd
```
