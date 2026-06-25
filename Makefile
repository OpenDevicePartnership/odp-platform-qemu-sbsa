# Primary Makefile for the ODP QEMU `virt` Platform firmware build system.
#
# SPDX-License-Identifier: MIT
#
include Common.mk

# ------------------------------------------------------------
# Default target — builds all artifacts (does not run tests).
# Use `make e2e-test` to run the full test suite (serial-link
# smoke test + e2e tests against the secure partition).
# ------------------------------------------------------------
all: mod
	$(MAKE) -C e2e-tests build

# ------------------------------------------------------------
# mod/ — secure-services, uefi, and ec live under mod/Makefile.
# Top-level just delegates so that mod-specific impl details
# (cargo invocations, build flavors, etc.) stay encapsulated.
# ------------------------------------------------------------
mod:
	$(MAKE) -C mod all

# Convenience aliases so `make ec`, `make uefi`, etc. still work from
# the top level. Each delegates to the like-named target in mod/Makefile.
secure-services secure-services-test uefi ec:
	$(MAKE) -C mod $@

# ------------------------------------------------------------
# Run QEMU using UEFI flash-only flow
# ------------------------------------------------------------
run:
	$(MAKE) -C mod/uefi run

# ------------------------------------------------------------
# Build OS image and boot it in QEMU
# ------------------------------------------------------------
run_os:
	$(MAKE) -C postbuild/os build/winvos.qcow2
	$(MAKE) -C mod/uefi run PATH_TO_OS=$(REPO_ROOT_IN_DEVCONTAINER)/postbuild/os/build/winvos.qcow2

# ------------------------------------------------------------
# Run E2E tests against the secure partition
# ------------------------------------------------------------
# Two phases:
#   1. Serial-link smoke test (EC<->host via PTY) using the default
#      secure-services build.
#   2. Full e2e suite — rebuild secure-services with test-bypass
#      features, rebuild uefi with the test SP embedded, run tests.
# Order matters: phase 2 clobbers the default secure-services binary,
# so the serial-link test must run first.
e2e-test: ec uefi
	$(MAKE) -C e2e-tests test-sp-ec-link
	$(MAKE) -C mod secure-services-test
	$(MAKE) -C mod uefi-only
	$(MAKE) -C e2e-tests test-sp-services

# ------------------------------------------------------------
# Clean everything
# ------------------------------------------------------------
clean:
	$(MAKE) -C mod clean
	$(MAKE) -C e2e-tests clean
	$(MAKE) -C postbuild/os clean
.PHONY: all mod secure-services secure-services-test uefi ec run e2e-test run_os clean
