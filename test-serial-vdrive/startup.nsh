# UEFI shell startup script for the serial-link smoke test.
#
# SPDX-License-Identifier: MIT
#

@echo -off
echo test-serial: SBSA reached UEFI shell, requesting shutdown
reset -s
