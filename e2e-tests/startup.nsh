@echo -off
for %a in fs4 fs3 fs2 fs1 fs0
  if exist %a:\thermal.efi then
    %a:\thermal.efi
    if exist %a:\tpm.efi then
      %a:\tpm.efi
    else
      echo [FAIL] TPM test binary tpm.efi not found on %a:
    endif
    if exist %a:\battery.efi then
      %a:\battery.efi
    else
      echo [FAIL] Battery test binary battery.efi not found on %a:
    endif
    if exist %a:\fwmgmt.efi then
      %a:\fwmgmt.efi
    else
      echo [FAIL] FwMgmt test binary fwmgmt.efi not found on %a:
    endif
    if exist %a:\notify.efi then
      %a:\notify.efi
    else
      echo [FAIL] Notify test binary notify.efi not found on %a:
    endif
    reset -s
    goto done
  endif
endfor
echo test EFIs not found on any filesystem
:done
