# shellcheck shell=bash
# Sourceable library — provides start_ec_qemu and discover_ec_pty.
# Do not execute directly.
#
# Required on PATH: qemu-system-riscv32, defmt-print, stdbuf, setsid, timeout
#
# Functions intentionally assign EC_PID in the *caller's* shell scope
# (no `local`) so the orchestrator's cleanup trap can reach the EC's
# session/process group via `kill -- -$EC_PID`.
#
# Shell options (set -o pipefail, etc.) are owned by the caller; this
# library does not modify them.

# start_ec_qemu <ec-elf> <stdout-log> <stderr-log> <serial-log> <timeout-secs>
#   Launches the EC QEMU (riscv32) inside its own session/process group via
#   `setsid` and sets EC_PID in the caller's shell to the session leader's
#   PID. The pipeline routes:
#     qemu stderr -> <stderr-log>
#     qemu stdout | stdbuf tee <stdout-log> | defmt-print -> <serial-log>
start_ec_qemu() {
    local elf="$1" out_log="$2" err_log="$3" serial_log="$4" timeout_s="$5"
    # Log files are pre-cleared by the orchestrator (`rm -f`); shell redirection
    # below creates them fresh. No truncation needed here.
    setsid bash -c "timeout $timeout_s qemu-system-riscv32 \
        -machine virt \
        -bios none \
        -kernel \"$elf\" \
        -semihosting \
        -display none \
        -serial pty \
        -monitor none \
        -no-reboot \
        2> \"$err_log\" \
        | stdbuf -oL tee \"$out_log\" \
        | stdbuf -oL defmt-print -e \"$elf\"" \
        >"$serial_log" 2>&1 &
    # SC2034: EC_PID is intentionally assigned in the caller's scope so the
    # orchestrator's cleanup trap can reach the process group; not unused.
    # shellcheck disable=SC2034
    EC_PID=$!
}

# discover_ec_pty <stdout-log> <stderr-log> [tenths-of-second-timeout=100]
#   Polls QEMU's log files for the `/dev/pts/N` PTY path it printed when
#   `-serial pty` allocated one. On success: prints the PTY path to stdout
#   and returns 0. On timeout: dumps both log files to stderr and returns 1.
discover_ec_pty() {
    local out_log="$1" err_log="$2" timeout="${3:-100}" i pty=""
    for ((i = 0; i < timeout; i++)); do
        # `-h` suppresses the `filename:` prefix grep emits when given multiple
        # files; without it the result includes "ec-qemu-stdout.log:/dev/pts/N".
        pty=$(grep -ahoE '/dev/pts/[0-9]+' "$out_log" "$err_log" 2>/dev/null \
            | head -1) || true
        if [ -n "$pty" ]; then
            echo "$pty"
            return 0
        fi
        sleep 0.1
    done
    {
        echo "ERROR: EC PTY path not reported within $((timeout / 10))s"
        echo "--- EC QEMU stdout ---"
        cat "$out_log" 2>/dev/null || echo "(empty)"
        echo "--- EC QEMU stderr ---"
        cat "$err_log" 2>/dev/null || echo "(empty)"
        echo "--- End EC QEMU logs ---"
    } >&2
    return 1
}
