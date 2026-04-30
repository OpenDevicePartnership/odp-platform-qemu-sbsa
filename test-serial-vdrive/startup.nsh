# @file startup.nsh
#
# UEFI shell startup script for serial-link smoke test
#
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: Apache-2.0

@echo -off
echo test-serial: SBSA reached UEFI shell, requesting shutdown
reset -s
