#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
PATINA_QEMU_DIR="$REPO_ROOT/mod/uefi/patina-qemu"
PLATFORM_DIR="$REPO_ROOT/mod/uefi/platform"
QEMU_VIRT_PKG_DIR="$PLATFORM_DIR/QemuArmVirtPkg"

DSC_PATH="QemuArmVirtPkg/OdpArmVirtPkg.dsc"
INF_PATH="QemuArmVirtPkg/AcpiTables/AcpiTables.inf"
BUILD_WRAPPER="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/BinWrappers/PosixLike/build"
CONF_SENTINEL="$PATINA_QEMU_DIR/Conf/.AutoGenIdFile.txt"
BASETOOLS_BIN_DIR="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/Bin/Linux-x86"

TARGET="${BUILD_TARGET:-DEBUG}"
TOOLCHAIN="${BUILD_TOOLCHAIN:-CLANGPDB}"
ARCH="${BUILD_ARCH:-AARCH64}"

ACPI_FILE_GUID="7E374E25-8E01-4FEE-87F2-390C23C606CD"
ODP_FV_GUID="9e21fd93-afa2-478e-aedc-dfba2573d992"

BUILD_DIR="$PATINA_QEMU_DIR/Build/OdpArmVirtPkg/${TARGET}_${TOOLCHAIN}"

usage() {
  cat <<'EOF'
Usage: build_acpi_tables.sh [options]

Builds QemuArmVirtPkg/AcpiTables/AcpiTables.inf and creates a separate
ODP firmware volume (odp.fd) containing the ACPI tables for QEMU arm-virt.

Options:
  -h, --help              Show this help.

Environment variables (optional):
  BUILD_TARGET            Build target. Default: DEBUG.
  BUILD_TOOLCHAIN         Toolchain tag. Default: CLANGPDB.
  BUILD_ARCH              Target architecture. Default: AARCH64.
EOF
}

log() {
  echo "[odp-build] $*"
}

fail() {
  echo "error: $*" >&2
  exit 1
}

# Parse minimal arguments
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;; # OK
  *) fail "unknown argument: $1" ;;
esac

# Validate prerequisites
[[ -d "$PATINA_QEMU_DIR" ]] || fail "missing patina-qemu workspace at $PATINA_QEMU_DIR"
[[ -f "$CONF_SENTINEL" ]] || fail "missing edk2 build configuration; run stuart_setup and stuart_update first"
[[ -f "$SCRIPT_DIR/$INF_PATH" ]] || fail "missing AcpiTables.inf at $SCRIPT_DIR/$INF_PATH"
[[ -f "$PLATFORM_DIR/$DSC_PATH" ]] || fail "missing OdpArmVirtPkg.dsc at $PLATFORM_DIR/$DSC_PATH"
[[ -x "$BUILD_WRAPPER" ]] || fail "missing build wrapper at $BUILD_WRAPPER"

# Setup environment
export WORKSPACE="$PATINA_QEMU_DIR"
export PACKAGES_PATH="$PLATFORM_DIR:$PATINA_QEMU_DIR/Platforms:$PATINA_QEMU_DIR/MU_BASECORE:$PATINA_QEMU_DIR/Common/MU:$PATINA_QEMU_DIR/Common/PATINA_EDK2:$PATINA_QEMU_DIR/Silicon/Arm/TFA:$PATINA_QEMU_DIR/Features/FFA"
export EDK_TOOLS_PATH="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools"
export CONF_PATH="$PATINA_QEMU_DIR/Conf"
export PATH="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/BinWrappers/PosixLike:$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/Bin/Linux-x86:$PATH"

ensure_basetools_c_tools() {
  if [[ -x "$BASETOOLS_BIN_DIR/GenSec" && -x "$BASETOOLS_BIN_DIR/GenFfs" ]]; then
    return
  fi
  log "building BaseTools C binaries"
  (cd "$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/Source/C" && make)
}



build_acpi_module() {
  log "building $INF_PATH"
  (
    cd "$PATINA_QEMU_DIR"
    "$BUILD_WRAPPER" \
      -p "$DSC_PATH" \
      -b "$TARGET" \
      -t "$TOOLCHAIN" \
      -a "$ARCH" \
      -m "$INF_PATH" \
      -D TPM2_ENABLE=TRUE \
      -D BUILDID_STRING=Unknown \
      -D MEMORY_PROTECTION=TRUE \
      -D SHIP_MODE=FALSE \
      -D ONE_CRYPTO_PATH="$PATINA_QEMU_DIR/MU_BASECORE/CryptoPkg/Binaries/onecrypto-bin_extdep" \
      -D SHARED_CRYPTO_PATH="$PATINA_QEMU_DIR/MU_BASECORE/CryptoPkg/Binaries/edk2-basecrypto-driver-bin_extdep" \
      -D DXE_CORE_PATH="$PATINA_QEMU_DIR/QemuPkg/Binaries/DXECORE.QEMU_extdep"
  )
}

find_acpi_ffs() {
  local ffs_glob
  local matches=()

  shopt -s nullglob
  ffs_glob="$BUILD_DIR/FV/Ffs/${ACPI_FILE_GUID}"*"/${ACPI_FILE_GUID}.ffs"
  matches=( $ffs_glob )
  shopt -u nullglob

  [[ ${#matches[@]} -gt 0 ]] || return 1
  printf '%s\n' "${matches[0]}"
}

generate_odp_firmware_volume() {
  log "generating ODP firmware volume from FDF"
  (
    cd "$PATINA_QEMU_DIR"
    GenFds \
      -f "$QEMU_VIRT_PKG_DIR/OdpArmVirtPkg.fdf" \
      -p "$QEMU_VIRT_PKG_DIR/OdpArmVirtPkg.dsc" \
      -o "$BUILD_DIR" \
      -t "$TOOLCHAIN" \
      -b "$TARGET" \
      -a "$ARCH"
  )
}

# Build
ensure_basetools_c_tools

build_acpi_module
ACPI_FFS=$(find_acpi_ffs) || fail "build did not produce ${ACPI_FILE_GUID}.ffs under $BUILD_DIR/FV/Ffs"

ODP_FV_OUTPUT="$BUILD_DIR/FV/ODP.fd"
generate_odp_firmware_volume

[[ -f "$ODP_FV_OUTPUT" ]] || fail "GenFds did not produce ODP.fd"

log "ODP firmware volume: $ODP_FV_OUTPUT"
log "FFS GUID: $ACPI_FILE_GUID"
log "FV GUID: $ODP_FV_GUID"
