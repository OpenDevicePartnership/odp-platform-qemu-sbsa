#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
PATINA_QEMU_DIR="$REPO_ROOT/mod/uefi/patina-qemu"
PLATFORM_DIR="$REPO_ROOT/mod/uefi/platform"

PLATFORM_BUILD_PY="$PATINA_QEMU_DIR/Platforms/QemuArmVirtPkg/PlatformBuild.py"
UPSTREAM_DSC_PATH="$PATINA_QEMU_DIR/Platforms/QemuArmVirtPkg/QemuArmVirtPkg.dsc"
DSC_PATH="QemuArmVirtPkg/QemuArmVirtPkg.acpi.generated.dsc"
GENERATED_DSC_PATH="$PLATFORM_DIR/$DSC_PATH"
INF_PATH="QemuArmVirtPkg/AcpiTables/AcpiTables.inf"
FMMT_PY="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/Source/Python/FMMT/FMMT.py"
BUILD_WRAPPER="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/BinWrappers/PosixLike/build"
CONF_SENTINEL="$PATINA_QEMU_DIR/Conf/.AutoGenIdFile.txt"
BASETOOLS_BIN_DIR="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/Bin/Linux-x86"

DEFAULT_TARGET="DEBUG"
DEFAULT_TOOLCHAIN="CLANGPDB"
DEFAULT_ARCH="AARCH64"
DEFAULT_FV_NAME="64074afe-340a-4be6-94ba-91b5b4d0f71e"
ACPI_FILE_GUID="7E374E25-8E01-4FEE-87F2-390C23C606CD"

TARGET="$DEFAULT_TARGET"
TOOLCHAIN="$DEFAULT_TOOLCHAIN"
ARCH="$DEFAULT_ARCH"
FV_NAME="$DEFAULT_FV_NAME"
INPUT_FIRMWARE=""

EXTRA_DEFINES=(
  "TPM2_ENABLE=TRUE"
  "ONE_CRYPTO_PATH=$PATINA_QEMU_DIR/MU_BASECORE/CryptoPkg/Binaries/onecrypto-bin_extdep"
  "SHARED_CRYPTO_PATH=$PATINA_QEMU_DIR/MU_BASECORE/CryptoPkg/Binaries/edk2-basecrypto-driver-bin_extdep"
  "DXE_CORE_PATH=$PATINA_QEMU_DIR/QemuPkg/Binaries/DXECORE.QEMU_extdep"
  "BUILDID_STRING=Unknown"
  "MEMORY_PROTECTION=TRUE"
  "SHIP_MODE=FALSE"
)

usage() {
  cat <<'EOF'
Usage: build_acpi_tables.sh [options]

Builds QemuArmVirtPkg/AcpiTables/AcpiTables.inf inside the existing patina-qemu
edk2 workspace and patches the resulting freeform FFS into an existing firmware
image.

Options:
  --firmware PATH         Input firmware image to patch.
  --fv-name NAME          Firmware volume GUID to patch. Default: FvMain GUID.
  --target NAME           Build target. Default: DEBUG.
  --toolchain NAME        Toolchain tag. Default: CLANGPDB.
  --arch NAME             Target architecture. Default: AARCH64.
  --define NAME=VALUE     Extra build define. Repeat as needed.
  -h, --help              Show this help.

Examples:
  build_acpi_tables.sh
  build_acpi_tables.sh --firmware /path/to/QEMU_EFI.fd
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

log() {
  echo "[acpi-patch] $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --firmware)
      [[ $# -ge 2 ]] || fail "--firmware requires a path"
      INPUT_FIRMWARE="$2"
      shift 2
      ;;
    --fv-name)
      [[ $# -ge 2 ]] || fail "--fv-name requires a value"
      FV_NAME="$2"
      shift 2
      ;;
    --target)
      [[ $# -ge 2 ]] || fail "--target requires a value"
      TARGET="$2"
      shift 2
      ;;
    --toolchain)
      [[ $# -ge 2 ]] || fail "--toolchain requires a value"
      TOOLCHAIN="$2"
      shift 2
      ;;
    --arch)
      [[ $# -ge 2 ]] || fail "--arch requires a value"
      ARCH="$2"
      shift 2
      ;;
    --define)
      [[ $# -ge 2 ]] || fail "--define requires NAME=VALUE"
      EXTRA_DEFINES+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

BUILD_DIR="$PATINA_QEMU_DIR/Build/QemuArmVirtPkg/${TARGET}_${TOOLCHAIN}"
DEFAULT_FIRMWARE="$BUILD_DIR/FV/QEMU_EFI.fd"

if [[ -z "$INPUT_FIRMWARE" ]]; then
  INPUT_FIRMWARE="$DEFAULT_FIRMWARE"
fi

[[ -d "$PATINA_QEMU_DIR" ]] || fail "missing patina-qemu workspace at $PATINA_QEMU_DIR"
[[ -f "$PLATFORM_BUILD_PY" ]] || fail "missing PlatformBuild.py at $PLATFORM_BUILD_PY"
[[ -f "$UPSTREAM_DSC_PATH" ]] || fail "missing upstream QemuArmVirtPkg.dsc at $UPSTREAM_DSC_PATH"
[[ -f "$CONF_SENTINEL" ]] || fail "missing edk2 build configuration; run stuart_setup and stuart_update first"
[[ -f "$SCRIPT_DIR/$INF_PATH" ]] || fail "missing AcpiTables.inf at $SCRIPT_DIR/$INF_PATH"
[[ -f "$FMMT_PY" ]] || fail "missing FMMT.py at $FMMT_PY"
[[ -x "$BUILD_WRAPPER" ]] || fail "missing build wrapper at $BUILD_WRAPPER"

export WORKSPACE="$PATINA_QEMU_DIR"
export PACKAGES_PATH="$PLATFORM_DIR:$PATINA_QEMU_DIR/Platforms:$PATINA_QEMU_DIR/MU_BASECORE:$PATINA_QEMU_DIR/Common/MU:$PATINA_QEMU_DIR/Common/PATINA_EDK2:$PATINA_QEMU_DIR/Silicon/Arm/TFA:$PATINA_QEMU_DIR/Features/FFA"
export EDK_TOOLS_PATH="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools"
export CONF_PATH="$PATINA_QEMU_DIR/Conf"
export PATH="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/BinWrappers/PosixLike:$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/Bin/Linux-x86:$PATH"
export PYTHONPATH="$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/Source/Python/FMMT:$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/Source/Python${PYTHONPATH:+:$PYTHONPATH}"

ensure_basetools_c_tools() {
  if [[ -x "$BASETOOLS_BIN_DIR/GenSec" && -x "$BASETOOLS_BIN_DIR/GenFfs" ]]; then
    return
  fi

  log "building BaseTools C binaries"
  (
    cd "$PATINA_QEMU_DIR/MU_BASECORE/BaseTools/Source/C"
    make
  )
}

prepare_platform_dsc() {
  local acpi_component_line="  QemuArmVirtPkg/AcpiTables/AcpiTables.inf"

  mkdir -p -- "$(dirname -- "$GENERATED_DSC_PATH")"
  awk -v insert_line="$acpi_component_line" '
    {
      raw = $0
      normalized = $0
      sub(/\r$/, "", normalized)
      print raw
      if (normalized == "  QemuPkg/AcpiPlatformDxe/AcpiPlatformDxe.inf") {
        print ""
        print insert_line
      }
    }
  ' "$UPSTREAM_DSC_PATH" > "$GENERATED_DSC_PATH"
}

cleanup() {
  rm -f -- "$GENERATED_DSC_PATH"
}

run_module_build() {
  local build_args=(
    -p "$DSC_PATH"
    -b "$TARGET"
    -t "$TOOLCHAIN"
    -a "$ARCH"
    -m "$INF_PATH"
  )
  local define

  for define in "${EXTRA_DEFINES[@]}"; do
    build_args+=( -D "$define" )
  done

  log "building $INF_PATH"
  (
    cd "$PATINA_QEMU_DIR"
    "$BUILD_WRAPPER" "${build_args[@]}"
  )
}

find_acpi_ffs() {
  local ffs_glob
  local matches=()

  shopt -s nullglob
  ffs_glob="$BUILD_DIR/FV/Ffs/${ACPI_FILE_GUID}"*"/${ACPI_FILE_GUID}.ffs"
  matches=( $ffs_glob )
  shopt -u nullglob

  if [[ ${#matches[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${matches[0]}"
}

patch_firmware() {
  local new_ffs="$1"
  local input_firmware="$2"
  local temp_output
  local extract_probe

  [[ -f "$input_firmware" ]] || fail "input firmware not found: $input_firmware"
  [[ -f "$new_ffs" ]] || fail "new FFS not found: $new_ffs"

  temp_output=$(mktemp "${input_firmware}.tmp.XXXXXX")
  extract_probe=$(mktemp "${input_firmware}.probe.XXXXXX")
  rm -f -- "$temp_output"
  rm -f -- "$extract_probe"

  log "patching $FV_NAME in $(basename -- "$input_firmware")"
  if python3 "$FMMT_PY" -e "$input_firmware" "$FV_NAME" "$ACPI_FILE_GUID" "$extract_probe" >/dev/null 2>&1 && [[ -f "$extract_probe" ]]; then
    if ! python3 "$FMMT_PY" -r "$input_firmware" "$FV_NAME" "$ACPI_FILE_GUID" "$new_ffs" "$temp_output" || [[ ! -f "$temp_output" ]]; then
      rm -f -- "$temp_output" "$extract_probe"
      fail "FMMT failed to replace ACPI FFS ${ACPI_FILE_GUID} in $FV_NAME"
    fi
  else
    log "ACPI FFS ${ACPI_FILE_GUID} not found in $FV_NAME; adding new entry"
    if ! python3 "$FMMT_PY" -a "$input_firmware" "$FV_NAME" "$new_ffs" "$temp_output" || [[ ! -f "$temp_output" ]]; then
      rm -f -- "$temp_output" "$extract_probe"
      fail "FMMT could not replace or add the ACPI FFS in $FV_NAME"
    fi
  fi
  rm -f -- "$extract_probe"

  extract_probe=$(mktemp "${input_firmware}.probe.XXXXXX")
  rm -f -- "$extract_probe"
  if ! python3 "$FMMT_PY" -e "$temp_output" "$FV_NAME" "$ACPI_FILE_GUID" "$extract_probe" >/dev/null 2>&1 || [[ ! -f "$extract_probe" ]]; then
    rm -f -- "$temp_output" "$extract_probe"
    fail "patched firmware does not contain ACPI FFS ${ACPI_FILE_GUID} in $FV_NAME"
  fi
  rm -f -- "$extract_probe"

  if [[ ! -f "$temp_output" ]]; then
    rm -f -- "$temp_output"
    fail "FMMT did not produce a patched firmware image"
  fi

  mv -- "$temp_output" "$input_firmware"
}

ensure_basetools_c_tools
prepare_platform_dsc
trap cleanup EXIT
run_module_build

ACPI_FFS=$(find_acpi_ffs) || fail "build completed but did not produce ${ACPI_FILE_GUID}.ffs under $BUILD_DIR/FV/Ffs"
patch_firmware "$ACPI_FFS" "$INPUT_FIRMWARE"

log "patched firmware written to $INPUT_FIRMWARE"
log "module FFS used: $ACPI_FFS"
