# UEFI shell startup script for E2E tests.
#
# SPDX-License-Identifier: MIT
#

@echo -off
for %a in fs4 fs3 fs2 fs1 fs0
  if exist %a:\thermal.efi then
    %a:\thermal.efi
    if exist %a:\tpm.efi then
      %a:\tpm.efi
    else
      echo [FAIL] TPM test binary tpm.efi not found on %a:
    endif
    reset -s
    goto done
  endif
endfor
echo test EFIs not found on any filesystem
:done
