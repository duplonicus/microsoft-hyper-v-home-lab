# 33 - Undo a Sysprepped REF01 that booted Windows instead of the DVD: power it off hard and go back to the "before Sysprep" checkpoint.
# Run on the HOST in an Administrator PowerShell. Same as Hyper-V Manager: REF01 > Turn Off, then Checkpoints > (after|before) Sysprep > Apply.
# Why: a generalized Windows that boots from its own disk starts first-time setup (specialize + OOBE) and stops being a clean image.
# Turn Off (not Shut Down): pulls the virtual power cord, so OOBE gets no further. Applying the checkpoint throws all of that away.
# Happened 2026-11-05: 32-boot-from-dvd.ps1's first run got no "press any key" prompt and REF01 went to OOBE's country screen.
$ErrorActionPreference = 'Stop'

if ((Get-VM -Name REF01).State -ne 'Off') { Stop-VM -Name REF01 -TurnOff -Force }
# Prefer "after Sysprep" (31a): already generalized, so no second Sysprep needed. Fall back to "before Sysprep".
$cp = Get-VMSnapshot -VMName REF01 -Name 'after Sysprep' -ErrorAction SilentlyContinue
if (-not $cp) { $cp = Get-VMSnapshot -VMName REF01 -Name 'before Sysprep' }
"Restoring checkpoint: $($cp.Name)"
Restore-VMSnapshot -VMSnapshot $cp -Confirm:$false
if ($cp.Name -eq 'after Sysprep') { "REF01 is generalized and off. Do NOT start it normally: run 32-boot-from-dvd.ps1 REF01 next." }
else { "REF01 is back before Sysprep. Start it (Audit Mode), run Sysprep (31), then 31a, then 32." }

Get-VM REF01 | Format-Table Name, State
Get-VMNetworkAdapter -VMName REF01 | Format-Table VMName, SwitchName, Connected
