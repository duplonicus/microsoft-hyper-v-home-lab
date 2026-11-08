# 35 - After the capture: delete REF01's checkpoints (which MERGES their changes into the base disks), then detach images.vhdx.
# Run on the HOST in an Administrator PowerShell, with REF01 OFF (wpeutil shutdown at Setup's prompt).
# Same as Hyper-V Manager: REF01 > Checkpoints > right-click the top one > Delete Checkpoint Subtree, wait for "Merging" to finish,
# then Settings > SCSI Controller > the images.vhdx Hard Drive > Remove.
# Why: since scripts 30/31a took checkpoints, every write went into differencing files (images_<GUID>.avhdx), including the whole
# ref.wim. The base images.vhdx still looks empty until the checkpoints are deleted and merged. Moving images.vhdx to PC01 before
# that would hand PC01 a disk WITHOUT ref.wim. (Found 2026-11-05 watching the capture: writes landed in images_658675F0...avhdx.)
# REF01 stays generalized after this. Don't start it normally (it would run OOBE); it's only kept to rebuild a v2 image later.
$ErrorActionPreference = 'Stop'
$vms = 'D:\home-lab\vms'

if ((Get-VM -Name REF01).State -ne 'Off') { throw 'REF01 is not off. At Setup''s prompt run:  wpeutil shutdown' }

Get-VMSnapshot -VMName REF01 | Format-Table Name, CreationTime
Get-VMSnapshot -VMName REF01 | Remove-VMSnapshot
"Merging checkpoints into the base disks..."
while ((Get-VM -Name REF01).Status -match 'Merg' -or (Get-ChildItem "$vms\REF01_*.avhdx", "$vms\images_*.avhdx" -ErrorAction SilentlyContinue)) {
    "  $((Get-VM -Name REF01).Status)"; Start-Sleep -Seconds 5
}
"Merge done."

Get-VMHardDiskDrive -VMName REF01 | Where-Object Path -like '*images.vhdx' | Remove-VMHardDiskDrive

Get-VMHardDiskDrive -VMName REF01 | Format-Table ControllerLocation, Path
Get-Item "$vms\images.vhdx" | Format-Table Name, @{n='GB';e={[math]::Round($_.Length/1GB,1)}}   # should now be ~the size of ref.wim + a bit
