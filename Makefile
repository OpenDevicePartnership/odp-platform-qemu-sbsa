# ODP SBSA Build file
#
# ## License
#
# Copyright (c) Microsoft Corporation.
#
# SPDX-License-Identifier: Apache-2.0


# ------------------------------------------------------------
# Workspace setup
# ------------------------------------------------------------
WORKSPACE ?= $(CURDIR)

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: bios

# ------------------------------------------------------------
# Build UEFI
# ------------------------------------------------------------
bios:
	@echo "=== Building BIOS ==="
	stuart_setup -c bios/Platforms/QemuSbsaPkg/PlatformBuild.py
	stuart_update -c bios/Platforms/QemuSbsaPkg/PlatformBuild.py
	stuart_build -c bios/Platforms/QemuSbsaPkg/PlatformBuild.py

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	@echo "=== Cleaning all components ==="

.PHONY: all bios clean