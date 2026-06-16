# shellcheck shell=bash
# Sourceable library — provides shared host QEMU args. Do not execute
# directly.
#
# SPDX-License-Identifier: MIT
#
# Required on PATH: qemu-system-aarch64, timeout
#
# Shell options (set -o pipefail, etc.) are owned by the caller.

# require_host_qemu_tools
#   Verifies the external tools this library (and the orchestrator that
#   drives it) need are on PATH. On any miss, prints the missing
#   commands to stderr and returns 1 so the orchestrator can fail loudly
#   at startup.
require_host_qemu_tools() {
    local cmd missing=()
    for cmd in qemu-system-aarch64 timeout; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    [ "${#missing[@]}" -eq 0 ] ||
        { echo "ERROR: missing required tools for host QEMU: ${missing[*]}" >&2; return 1; }
}

# require_host_serial_tee_tools
#   Extra tools needed only when the host orchestrator streams serial
#   through a FIFO + tee (SERIAL_TEE=1). Kept separate from
#   require_host_qemu_tools so SERIAL_TEE=0 runs don't demand them.
require_host_serial_tee_tools() {
    local cmd missing=()
    for cmd in mkfifo tee; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    [ "${#missing[@]}" -eq 0 ] ||
        { echo "ERROR: missing required tools for SERIAL_TEE=1: ${missing[*]}" >&2; return 1; }
}

# set_host_pflash_tpm_args <bios-fv-dir> <swtpm-sock>
#   Sets HOST_PFLASH_TPM_ARGS in the caller's scope (no `local`,
#   matching lib/swtpm.sh's start_swtpm/SWTPM_PID pattern). The array
#   contains the shared host QEMU args used by both test scripts:
#   pflash dual-unit (SECURE_FLASH0 + QEMU_EFI), the tpm chardev +
#   tpmdev pair, and the tpm-tis-device front-end that maps the CRB
#   MMIO region on the `virt` machine (no platform default).
set_host_pflash_tpm_args() {
    local bios_fv_dir="$1" swtpm_sock="$2"
    HOST_PFLASH_TPM_ARGS=(
        -drive "if=pflash,format=raw,unit=0,file=$bios_fv_dir/SECURE_FLASH0.fd"
        -drive "if=pflash,format=raw,unit=1,file=$bios_fv_dir/QEMU_EFI.fd,readonly=on"
        -chardev "socket,id=chrtpm,path=$swtpm_sock"
        -tpmdev "emulator,id=tpm0,chardev=chrtpm"
        -device "tpm-tis-device,tpmdev=tpm0"
    )
}
