# shellcheck shell=bash
# Sourceable library — provides start_swtpm and wait_for_swtpm_socket.
# Do not execute directly.
#
# Required on PATH: swtpm
#
# Functions intentionally assign SWTPM_PID in the *caller's* shell scope
# (no `local`) so the orchestrator's cleanup trap can reach it.
#
# Shell options (set -o pipefail, etc.) are owned by the caller; this
# library does not modify them.

# start_swtpm <state-dir> <socket-path> <log-path>
#   Launches swtpm in the background and sets SWTPM_PID in the caller's
#   shell. Does NOT wait for the socket to become ready — call
#   wait_for_swtpm_socket afterwards.
start_swtpm() {
    local state_dir="$1" socket="$2" log="$3"
    mkdir -p "$state_dir"
    swtpm socket \
        --tpmstate "dir=$state_dir" \
        --ctrl "type=unixio,path=$socket" \
        --tpm2 \
        --log "level=20,file=$log" &
    # SC2034: SWTPM_PID is intentionally assigned in the caller's scope so the
    # orchestrator's cleanup trap can reach it; not unused.
    # shellcheck disable=SC2034
    SWTPM_PID=$!
}

# wait_for_swtpm_socket <socket-path> [tenths-of-second-timeout=50]
#   Polls until the unix-domain socket exists or the timeout elapses.
#   Returns 0 on ready, 1 on timeout (with an error message on stderr).
wait_for_swtpm_socket() {
    local socket="$1" timeout="${2:-50}" i
    for ((i = 0; i < timeout; i++)); do
        [ -S "$socket" ] && return 0
        sleep 0.1
    done
    echo "ERROR: swtpm socket not created at $socket within $((timeout / 10))s" >&2
    return 1
}
