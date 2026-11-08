# 29 - Last checks and cleanup inside REF01 before Sysprep. Run INSIDE REF01 (Audit Mode) in an Administrator PowerShell.
# Get it there with scripts/26c-push-scripts-to-vm.ps1 REF01, then:  C:\LabScripts\29-ref01-pre-sysprep.ps1
# Same as: Power settings > never sleep/turn off screen; manage-bde -status; checking for a pending restart;
# Settings > Remote Desktop > Off; net user Administrator ""; deleting C:\LabScripts.
# Stops BEFORE changing anything if a Sysprep blocker is found (BitLocker on, restart pending).
# Sources (read 2026-11-05): Learn "Boot Windows to Audit Mode or OOBE" (screen-saver lockout), "Sysprep (Generalize) a Windows
# installation" (Store apps), "Enable and Disable the Built-in Administrator Account" (password kept on client editions);
# 24H2+ BitLocker reports are community posts on Microsoft Q&A, not a Learn page.
$ErrorActionPreference = 'Stop'

# 1. Never let the screen lock: Learn says the Audit Mode Administrator is disabled right after logon, so a locked
#    session can't be signed back into.
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0
"Screen/sleep timeouts: off"

# 2. Blockers. Collect them all, then stop if any.
$blockers = @()
$bl = Get-BitLockerVolume -MountPoint C:
"BitLocker C:  VolumeStatus=$($bl.VolumeStatus)  ProtectionStatus=$($bl.ProtectionStatus)"
if ($bl.VolumeStatus -ne 'FullyDecrypted') { $blockers += "C: is encrypted: run  manage-bde -off C:  and wait until  manage-bde -status C:  says Fully Decrypted" }

$pending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
           (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
"Restart pending (Windows servicing/Update): $pending"
if ($pending) { $blockers += 'A restart is pending: Restart-Computer (it comes back in Audit Mode), then re-run this script' }

if ($blockers) { $blockers | ForEach-Object { Write-Warning $_ }; throw 'Fix the blockers above first. Nothing was changed except the power settings.' }

# 3. Suspects for the classic Sysprep failure: Store apps installed/updated for this user but not provisioned for all users.
#    Informational only (the exact verdict is in Sysprep's own log). Empty = good.
$provisioned = (Get-AppxProvisionedPackage -Online).PackageName
$suspects = Get-AppxPackage | Where-Object { $_.SignatureKind -eq 'Store' -and -not $_.IsFramework -and $provisioned -notcontains $_.PackageFullName }
"Store packages not provisioned for all users: $(@($suspects).Count)"
$suspects | Format-Table Name, Version

# 4. Cleanup so the image doesn't ship lab-only settings
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 1   # Remote Desktop off
Disable-NetFirewallRule -DisplayGroup 'Remote Desktop'
cmd /c 'net user Administrator ""'      # back to blank (via cmd: PowerShell 5.1 drops "" when calling native programs)
"Remote Desktop off, Administrator password blank again"
Remove-Item C:\LabScripts -Recurse -Force   # PowerShell has already loaded this script, so deleting its folder is fine
"C:\LabScripts deleted. Next: on the HOST run scripts\30 (disconnect network + checkpoint), then Sysprep here."
