# shellcheck shell=bash
# Sourceable library — provides shared SBSA QEMU args. Do not execute
# directly.
#
# SPDX-License-Identifier: MIT
#
# Required on PATH: qemu-system-aarch64
#
# Shell options (set -o pipefail, etc.) are owned by the caller.

# set_sbsa_pflash_tpm_args <bios-fv-dir> <swtpm-sock>
#   Sets SBSA_PFLASH_TPM_ARGS in the caller's scope (no `local`,
#   matching lib/swtpm.sh's start_swtpm/SWTPM_PID pattern). The array
#   contains the shared SBSA QEMU args used by both test scripts:
#   pflash dual-unit (SECURE_FLASH0 + QEMU_EFI), the tpm chardev +
#   tpmdev pair, and the tpm-tis-device front-end that maps the CRB
#   MMIO region on the `virt` machine (no platform default).
set_sbsa_pflash_tpm_args() {
    local bios_fv_dir="$1" swtpm_sock="$2"
    SBSA_PFLASH_TPM_ARGS=(
        -drive "if=pflash,format=raw,unit=0,file=$bios_fv_dir/SECURE_FLASH0.fd"
        -drive "if=pflash,format=raw,unit=1,file=$bios_fv_dir/QEMU_EFI.fd,readonly=on"
        -chardev "socket,id=chrtpm,path=$swtpm_sock"
        -tpmdev "emulator,id=tpm0,chardev=chrtpm"
        -device "tpm-tis-device,tpmdev=tpm0"
    )
}
