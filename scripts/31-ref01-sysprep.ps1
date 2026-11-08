# 31 - Generalize REF01 with Sysprep. Run INSIDE REF01 (Audit Mode) in an Administrator PowerShell, AFTER scripts 29 (in REF01)
# and 30 (host: network off + "before Sysprep" checkpoint). Typed by hand on 2026-11-05 (29 deletes C:\LabScripts); this file is the record.
# Same as the System Preparation Tool window: System Cleanup Action "Enter System Out-of-Box Experience (OOBE)", tick Generalize,
# Shutdown Options "Shutdown", OK.
# /generalize = strip what makes this PC unique (SID, hardware state, logs, name); /oobe = next boot runs first-time setup;
# /shutdown = power off so the generalized state is frozen for capture. No /mode:vm: that's only for a VHD staying on the same
# hypervisor (Learn "Sysprep (Generalize) a Windows installation", read 2026-11-05); ref.wim must work on any hardware.
# If it fails: C:\Windows\System32\Sysprep\Panther\setuperr.log (and setupact.log). Then Apply the checkpoint, fix, run again.
# After it shuts down: do NOT start REF01 normally. Next is scripts\32-boot-from-dvd.ps1 REF01 (host).
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown
