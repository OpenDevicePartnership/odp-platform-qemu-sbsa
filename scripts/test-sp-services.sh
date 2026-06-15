#!/usr/bin/env bash
# Run the e2e test suite against the secure partition
#
# SPDX-License-Identifier: MIT
#
# Owns the long-lived child processes (swtpm + host QEMU), sets up the
# cleanup trap, and performs post-run verification by parsing the
# captured serial log.
#
# Run `test-sp-services.sh --help` for usage. Must be executed inside the
# odp-platform-qemu-sbsa devcontainer (requires swtpm, qemu-system-aarch64,
# timeout, tee on PATH).

set -o pipefail
# Intentionally NOT `set -e`: we use `cmd || EXIT=$?` patterns and rely
# on explicit exit codes for the QEMU run + log parsing. test-sp-ec-link.sh
# documents the same rationale (see v1.1 hardening cycle).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/swtpm.sh
source "$SCRIPT_DIR/lib/swtpm.sh"
# shellcheck source=lib/host-qemu.sh
source "$SCRIPT_DIR/lib/host-qemu.sh"

usage() {
    cat <<'EOF'
Usage: test-sp-services.sh --bios-fv-dir DIR --build-dir DIR --vdrive-dir DIR \
                           --coverage-plugin PATH --coverage-log PATH \
                           [--host-timeout N] [--serial-tee 0|1] -- <qemu-common-args...>

  --bios-fv-dir      Directory containing SECURE_FLASH0.fd and QEMU_EFI.fd
  --build-dir        Build/ directory (test-output.log, swtpm state, etc. live here)
  --vdrive-dir       FAT drive directory exposed to UEFI shell (test EFIs + startup.nsh)
  --coverage-plugin  Path to TCG coverage plugin (.so)
  --coverage-log     Path to write QEMU coverage PC trace
  --host-timeout     Seconds for host QEMU run (default: 180)
  --serial-tee       1 = tee QEMU serial to stdout AND file; 0 = file only (default: 0)

After --, all remaining args are passed verbatim to qemu-system-aarch64
(typically the QEMU_COMMON_ARGS from Common.mk).

Exit codes:
  0  — banner present, "N passed, 0 failed" line present, QEMU exit 0
  1  — banner missing, [FAIL] present, timed out, or other failure
EOF
}

# ----- arg parsing -----
BIOS_FV_DIR=""
BUILD_DIR=""
VDRIVE_DIR=""
COVERAGE_PLUGIN=""
COVERAGE_LOG=""
HOST_TIMEOUT=180
SERIAL_TEE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bios-fv-dir)     BIOS_FV_DIR="$2";     shift 2 ;;
        --build-dir)       BUILD_DIR="$2";       shift 2 ;;
        --vdrive-dir)      VDRIVE_DIR="$2";      shift 2 ;;
        --coverage-plugin) COVERAGE_PLUGIN="$2"; shift 2 ;;
        --coverage-log)    COVERAGE_LOG="$2";    shift 2 ;;
        --host-timeout)    HOST_TIMEOUT="$2";    shift 2 ;;
        --serial-tee)      SERIAL_TEE="$2";      shift 2 ;;
        --help|-h)         usage; exit 0 ;;
        --)                shift; break ;;
        *) echo "ERROR: unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

for var in BIOS_FV_DIR BUILD_DIR VDRIVE_DIR COVERAGE_PLUGIN COVERAGE_LOG; do
    if [ -z "${!var}" ]; then
        echo "ERROR: --${var,,} (translated from \$$var) is required" >&2
        usage >&2
        exit 2
    fi
done

QEMU_COMMON_ARGS=("$@")

# ----- paths -----
SWTPM_DIR="$BUILD_DIR/tpm"
SWTPM_SOCK="$SWTPM_DIR/swtpm-sock"
SWTPM_LOG="$BUILD_DIR/swtpm.log"
TEST_OUTPUT="$BUILD_DIR/test-output.log"
QEMU_EXIT_FILE="$BUILD_DIR/qemu-exit-code"

mkdir -p "$BUILD_DIR"
rm -f "$SWTPM_SOCK"

# ----- swtpm -----
start_swtpm "$SWTPM_DIR" "$SWTPM_SOCK" "$SWTPM_LOG"
if ! wait_for_swtpm_socket "$SWTPM_SOCK"; then
    kill "$SWTPM_PID" 2>/dev/null
    exit 1
fi

# ----- cleanup trap -----
cleanup() {
    local sig=$?
    [ -n "${QEMU_PID:-}" ] && kill "$QEMU_PID" 2>/dev/null
    kill_swtpm
    wait 2>/dev/null
    exit "$sig"
}
trap cleanup EXIT INT TERM

# ----- QEMU launch -----
set_host_pflash_tpm_args "$BIOS_FV_DIR" "$SWTPM_SOCK"

QEMU_ARGS=(
    "${QEMU_COMMON_ARGS[@]}"
    -plugin "file=$COVERAGE_PLUGIN,outfile=$COVERAGE_LOG"
    "${HOST_PFLASH_TPM_ARGS[@]}"
    -drive "file=fat:rw:$VDRIVE_DIR,format=raw,media=disk"
    -display none
    -no-reboot
)

if [ "$SERIAL_TEE" = "1" ]; then
    timeout "$HOST_TIMEOUT" qemu-system-aarch64 "${QEMU_ARGS[@]}" -serial stdio 2>&1 \
        | tee "$TEST_OUTPUT" &
    QEMU_PID=$!
else
    timeout "$HOST_TIMEOUT" qemu-system-aarch64 "${QEMU_ARGS[@]}" \
        -serial "file:$TEST_OUTPUT" &
    QEMU_PID=$!
fi

wait "$QEMU_PID"
QEMU_EXIT=$?
echo "$QEMU_EXIT" > "$QEMU_EXIT_FILE"

# Stop swtpm before result analysis (frees the socket).
kill_swtpm

# ----- result analysis -----
echo "=== Test output summary ==="
grep -E "\[(PASS|FAIL)\]" "$TEST_OUTPUT" || true
echo ""

if ! grep -q "EC Secure Partition E2E Tests" "$TEST_OUTPUT"; then
    echo "RESULT: TESTS NEVER RAN (banner not found in output)"
    exit 1
elif grep -q "\[FAIL\]" "$TEST_OUTPUT"; then
    echo "RESULT: SOME TESTS FAILED"
    exit 1
elif [ "$QEMU_EXIT" = "0" ] && grep -qE '^--- Results: [0-9]+ passed, 0 failed ---$' "$TEST_OUTPUT"; then
    echo "RESULT: ALL TESTS PASSED"
    exit 0
elif [ "$QEMU_EXIT" = "124" ]; then
    echo "RESULT: TIMED OUT (no test output seen)"
    exit 1
else
    echo "RESULT: NO TEST OUTPUT FOUND (exit code $QEMU_EXIT)"
    exit 1
fi
