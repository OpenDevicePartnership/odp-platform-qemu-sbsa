#!/usr/bin/env bash
# Thin wrapper around qemu-system-aarch64 that wires in the external embedded
# controller (EC) co-simulation chardev sockets.
#
# SPDX-License-Identifier: MIT
#
# This lives in *this* repo (not the patina-qemu submodule) so the EC<->host
# virtual I2C/GPIO wiring is reproducible without patching patina's QemuRunner
# plugin. `make run` passes this script as the QEMU_PATH build var; patina's
# QemuRunner then invokes it exactly like the real qemu binary.
#
# Behaviour:
#   - Forwards all args to the real qemu binary ($REAL_QEMU, default the
#     devcontainer's /usr/local/bin/qemu-system-aarch64).
#   - When the EC sockets exist, appends the two client chardevs the custom
#     ARM virt machine looks up by id ("ec-i2c-controller" for the socket-backed
#     I2C controller, "gpio0" for the PL061 line behind the i2c-hid interrupt).
#     The EC QEMU instance creates these socket *servers*; we connect as a
#     client (server=off). `reconnect-ms` makes the host keep retrying the
#     connection, so restarting just the EC (`make run_ec`) while the host
#     keeps running transparently reconnects to the new EC instance. If the
#     sockets are absent (plain `make run` with no EC), nothing is appended and
#     qemu boots normally.
#   - Passes through untouched for `--version`/`-version` probes so patina's
#     QueryQemuVersion keeps working.

set -euo pipefail

REAL_QEMU="${REAL_QEMU:-/usr/local/bin/qemu-system-aarch64}"
EC_I2C_SOCK="${EC_I2C_SOCK:-/tmp/qemu-ec-i2c.sock}"
EC_GPIO_SOCK="${EC_GPIO_SOCK:-/tmp/qemu-ec-gpio.sock}"

# Reconnect retry interval (milliseconds) for the client chardevs. Lets the
# host survive the EC restarting underneath it and reconnect on its own.
EC_RECONNECT_MS="${EC_RECONNECT_MS:-1000}"

# Version/help probes must not get extra device args appended.
for arg in "$@"; do
    case "$arg" in
        --version | -version)
            exec "$REAL_QEMU" "$@"
            ;;
    esac
done

extra=()
if [ -S "$EC_I2C_SOCK" ]; then
    extra+=(-chardev "socket,id=ec-i2c-controller,path=${EC_I2C_SOCK},server=off,reconnect-ms=${EC_RECONNECT_MS}")
fi
if [ -S "$EC_GPIO_SOCK" ]; then
    extra+=(-chardev "socket,id=gpio0,path=${EC_GPIO_SOCK},server=off,reconnect-ms=${EC_RECONNECT_MS}")
fi

exec "$REAL_QEMU" "$@" "${extra[@]}"
