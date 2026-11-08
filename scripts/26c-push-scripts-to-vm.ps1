# 26c - copy every lab script into a VM's C:\LabScripts, with no credentials, no network, no clipboard.
# Uses Hyper-V Copy-VMFile over the VM bus (needs the VM's "Guest Service Interface" integration service, which this turns on).
# Run on the HOST in an Administrator PowerShell, from this scripts folder:   .\26c-push-scripts-to-vm.ps1 REF01
# Then inside the VM (short enough to type; Tab completes the file name):
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   C:\LabScripts\28<Tab>
# Why not 26b-run-in-vm.ps1 (PowerShell Direct) on REF01: it returned "The credential is invalid" for the Audit Mode Administrator
# on 2026-11-05 even though the same password signs in inside the VM. Cause NOT found. Copy-VMFile needs no guest account.
# Before Sysprep: delete C:\LabScripts in the VM so the scripts don't ship in the image (IMAGING.md step 3).
# Source: Learn "Copy-VMFile" (read 2026-11-05). Safe to re-run: -Force overwrites older copies.
param([Parameter(Mandatory, Position = 0)][string]$VM)
$ErrorActionPreference = 'Stop'

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ((Get-VM -Name $VM).State -ne 'Running') { throw "$VM is not running." }

# Guest Service Interface is off by default; Copy-VMFile needs it
Enable-VMIntegrationService -VMName $VM -Name 'Guest Service Interface'

# Stage on a local host disk first: the Hyper-V service (not you) reads the source file, and most likely can't see
# \\wsl.localhost (a per-user WSL path; NOT tested, staging just avoids the question)
$stage = Join-Path $env:TEMP 'labscripts'
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item "$dir\*.ps1" $stage -Force

foreach ($f in Get-ChildItem "$stage\*.ps1") {
    Copy-VMFile -Name $VM -SourcePath $f.FullName -DestinationPath "C:\LabScripts\$($f.Name)" -CreateFullPath -FileSource Host -Force
}
"Copied $((Get-ChildItem "$stage\*.ps1").Count) scripts to $VM`:C:\LabScripts"
