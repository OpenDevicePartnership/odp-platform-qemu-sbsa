# Scripts

## Overview

This directory contains helper scripts for building, testing, and managing the
development environment for the ODP QEMU SBSA Platform.

## Contents

| Path | Description |
| --- | --- |
| `dc-run.sh` | Dispatch commands inside or outside the devcontainer |
| `test-serial.sh` | Orchestrate the EC-to-SBSA serial-link smoke test |
| `test-e2e.sh` | Run the E2E test suite against the secure partition |
| `push-devcontainer-cache.sh` | Rebuild and push devcontainer image cache to GHCR |
| `lib/swtpm.sh` | Sourceable library for swtpm (Software TPM) management |
| `lib/ec-qemu.sh` | Sourceable library for EC QEMU instance management |

## Usage

Scripts are typically invoked via `make` targets from the root Makefile.
The `dc-run.sh` script handles transparent devcontainer dispatch, so other
scripts work seamlessly both inside and outside the container.
