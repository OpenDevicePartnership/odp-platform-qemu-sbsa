#!/usr/bin/env bash
# scripts/test-serial.sh — Orchestrate the EC ↔ SBSA serial-link test.
#
# Owns the long-lived child processes (swtpm + EC QEMU + SBSA QEMU),
# sets up the cleanup trap, and performs post-run verification.
#
# Run `test-serial.sh --help` for usage. Must be executed inside the
# odp-platform-qemu-sbsa devcontainer (requires swtpm, qemu-system-riscv32,
# qemu-system-aarch64, defmt-print, stdbuf, setsid, timeout, pkill on PATH).

set -o pipefail
# Intentionally NOT `set -e`: we use `cmd || EXIT=$?` patterns and the v1.1
# hardening cycle showed -e interferes with timeout(1) exit handling.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/swtpm.sh
source "$SCRIPT_DIR/lib/swtpm.sh"
# shellcheck source=lib/ec-qemu.sh
source "$SCRIPT_DIR/lib/ec-qemu.sh"

usage() {
    cat <<'EOF'
Usage: test-serial.sh --ec-elf PATH --bios-fv-dir DIR --build-dir DIR \
                      [--ec-timeout N] [--sbsa-timeout N] -- <qemu-common-args...>

  --ec-elf        EC firmware ELF (riscv32)
  --bios-fv-dir   Directory containing SECURE_FLASH0.fd and QEMU_EFI.fd
  --build-dir     Build/ directory (logs and swtpm-state live here)
  --ec-timeout    Seconds for EC QEMU run (default: 30)
  --sbsa-timeout  Seconds for SBSA QEMU run (default: 60)
  --              Everything after this is forwarded verbatim to
                  qemu-system-aarch64 as the SBSA common args (machine,
                  cpu, mem, smbios, etc.)

Must run inside the odp-platform-qemu-sbsa devcontainer.

Exits 0 on PASS, non-zero on FAILURE. The first failure mode wins:
  - Setup error (swtpm socket / EC PTY discovery) -> exits 1
  - SBSA QEMU non-zero exit -> exits with that code (verification skipped)
  - EC boot string missing  -> exits 1 (after SBSA succeeded)
EOF
    exit "${1:-0}"
}

EC_ELF=""
BIOS_FV_DIR=""
BUILD_DIR=""
EC_TIMEOUT=30
SBSA_TIMEOUT=60

require_arg() {
    # require_arg <flag-name> <value-or-empty>
    [ -n "$2" ] || { echo "ERROR: $1 requires a value" >&2; exit 1; }
}

while [ $# -gt 0 ]; do
    case "$1" in
        --ec-elf)       require_arg "$1" "${2-}"; EC_ELF="$2"; shift 2 ;;
        --bios-fv-dir)  require_arg "$1" "${2-}"; BIOS_FV_DIR="$2"; shift 2 ;;
        --build-dir)    require_arg "$1" "${2-}"; BUILD_DIR="$2"; shift 2 ;;
        --ec-timeout)   require_arg "$1" "${2-}"; EC_TIMEOUT="$2"; shift 2 ;;
        --sbsa-timeout) require_arg "$1" "${2-}"; SBSA_TIMEOUT="$2"; shift 2 ;;
        -h|--help)      usage 0 ;;
        --)             shift; break ;;
        *)              echo "Unknown arg: $1" >&2; usage 1 ;;
    esac
done
# Remaining "$@" is the SBSA QEMU common args (smbios, machine, cpu, etc.)

if [ -z "$EC_ELF" ] || [ -z "$BIOS_FV_DIR" ] || [ -z "$BUILD_DIR" ]; then
    echo "ERROR: --ec-elf, --bios-fv-dir, and --build-dir are required" >&2
    usage 1
fi

# Validate timeouts at parse time. start_ec_qemu interpolates $timeout_s into
# an inner `bash -c` string (via setsid), so non-numeric input would risk
# command injection or an empty-`timeout` syntax error inside the inner shell.
# The library trusts its caller; the orchestrator is the right place to gate.
# Reject empty, non-digit, and zero in one pattern.
case "$EC_TIMEOUT" in
    ''|*[!0-9]*|0) echo "ERROR: --ec-timeout must be a positive integer (got: $EC_TIMEOUT)" >&2; exit 1 ;;
esac
case "$SBSA_TIMEOUT" in
    ''|*[!0-9]*|0) echo "ERROR: --sbsa-timeout must be a positive integer (got: $SBSA_TIMEOUT)" >&2; exit 1 ;;
esac

SWTPM_STATE="$BUILD_DIR/swtpm-state"
SWTPM_SOCK="$SWTPM_STATE/swtpm-sock"
SWTPM_LOG="$BUILD_DIR/swtpm.log"
EC_OUT_LOG="$BUILD_DIR/ec-qemu-stdout.log"
EC_ERR_LOG="$BUILD_DIR/ec-qemu-stderr.log"
EC_SERIAL_LOG="$BUILD_DIR/ec-serial-output.log"
SBSA_SERIAL_LOG="$BUILD_DIR/sbsa-serial-output.log"

EC_PID=""
SWTPM_PID=""

# Tear down the EC session (no-op if EC_PID is unset).
#
# EC_PID is the session leader of a session created by `setsid` (in
# ec-qemu.sh). Bash auto-enables job control for session-leader children,
# which puts each pipeline stage (timeout/tee/defmt-print) in its OWN
# process group inside the session — so a single `kill -- -$EC_PID` only
# signals the leader's own pgrp and leaks `timeout` + `qemu-system-riscv32`.
# Signal the whole session via `pkill -s` so every descendant process group
# is reached, then `kill -- -$EC_PID` as a belt-and-braces fallback.
kill_ec_session() {
    [ -n "$EC_PID" ] || return 0
    pkill -TERM -s "$EC_PID" 2>/dev/null
    kill -- "-$EC_PID" 2>/dev/null
    wait "$EC_PID" 2>/dev/null
}

# shellcheck disable=SC2329  # invoked via `trap ... EXIT` below
cleanup() {
    # SC2317: invoked via `trap ... EXIT`, not statically reachable.
    # shellcheck disable=SC2317
    kill_ec_session
    # shellcheck disable=SC2317
    if [ -n "$SWTPM_PID" ]; then
        kill "$SWTPM_PID" 2>/dev/null
        wait "$SWTPM_PID" 2>/dev/null
    fi
    # shellcheck disable=SC2317
    true
}
trap cleanup EXIT

mkdir -p "$BUILD_DIR" "$SWTPM_STATE"
rm -f "$EC_OUT_LOG" "$EC_ERR_LOG" "$EC_SERIAL_LOG" "$SBSA_SERIAL_LOG" "$SWTPM_SOCK"

# 1. swtpm
start_swtpm "$SWTPM_STATE" "$SWTPM_SOCK" "$SWTPM_LOG"
wait_for_swtpm_socket "$SWTPM_SOCK" || {
    echo "--- swtpm log ($SWTPM_LOG) ---" >&2
    cat "$SWTPM_LOG" >&2 2>/dev/null || echo "(empty or missing)" >&2
    echo "--- end swtpm log ---" >&2
    exit 1
}

# 2. EC QEMU + PTY discovery
start_ec_qemu "$EC_ELF" "$EC_OUT_LOG" "$EC_ERR_LOG" "$EC_SERIAL_LOG" "$EC_TIMEOUT"
PTY=$(discover_ec_pty "$EC_OUT_LOG" "$EC_ERR_LOG") || exit 1
echo "EC PTY: $PTY — launching SBSA QEMU"

# 3. SBSA QEMU
SBSA_EXIT=0
timeout "$SBSA_TIMEOUT" \
    qemu-system-aarch64 \
        "$@" \
        -drive "if=pflash,format=raw,unit=0,file=$BIOS_FV_DIR/SECURE_FLASH0.fd" \
        -drive "if=pflash,format=raw,unit=1,file=$BIOS_FV_DIR/QEMU_EFI.fd,readonly=on" \
        -chardev "socket,id=chrtpm,path=$SWTPM_SOCK" \
        -tpmdev "emulator,id=tpm0,chardev=chrtpm" \
        -chardev "serial,id=ec-link,path=$PTY" \
        -serial "file:$SBSA_SERIAL_LOG" \
        -serial "chardev:ec-link" \
        -drive "file=fat:rw:test-serial-vdrive,format=raw,media=disk" \
        -display none \
        -no-reboot \
    || SBSA_EXIT=$?

# 4. SBSA failure short-circuits before verification (matches original recipe).
if [ "$SBSA_EXIT" -ne 0 ]; then
    echo "SBSA QEMU exited with code $SBSA_EXIT" >&2
    exit "$SBSA_EXIT"
fi

# 5. Tear down the EC pipeline BEFORE verification so that defmt-print's
# block-buffered stdout (redirected to a regular file) is fully flushed to
# $EC_SERIAL_LOG before we grep it. The original Makefile recipe got this
# for free: verification ran in a separate shell after the bash -lc subshell's
# EXIT trap had already reaped EC. Clear EC_PID so the EXIT trap below
# doesn't try to tear it down a second time.
kill_ec_session
EC_PID=""

# 6. Verification (only on SBSA success).
PASS=true
if grep -q "Starting uart service" "$EC_SERIAL_LOG" 2>/dev/null; then
    echo "EC: boot successful (PTY serial backend)"
else
    echo "=== EC serial output ==="
    cat "$EC_SERIAL_LOG" 2>/dev/null || echo "(empty)"
    echo "=== End EC serial output ==="
    echo "EC: boot FAILED — 'Starting uart service' not found"
    PASS=false
fi

if [ -s "$SBSA_SERIAL_LOG" ]; then
    echo "SBSA: produced serial output (PTY connected)"
else
    echo "SBSA: WARNING — no serial output captured (may be OK if boot is slow)"
fi

if "$PASS"; then
    echo "RESULT: SERIAL LINK TEST PASSED"
    exit 0
else
    echo "RESULT: SERIAL LINK TEST FAILED"
    exit 1
fi
