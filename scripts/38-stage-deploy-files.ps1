# 38 - Put the deployment scripts on the Images disk (next to ref.wim), so WinPE can run them: our "deployment USB stick".
# Run on the HOST in an Administrator PowerShell, with the VM that has images.vhdx attached turned OFF (a .vhdx can't be open twice).
# Same as: Disk Management > Action > Attach VHD (images.vhdx), copy the files into a Deploy folder in Explorer, then Detach VHD.
# Why: Microsoft's own flow keeps CreatePartitions-UEFI.txt on the USB stick with the image (Learn "UEFI/GPT-based hard drive
# partitions"). Copy-VMFile (26c) can't help here: Setup's WinPE doesn't run Hyper-V's guest services.
# Safe to re-run: files are overwritten; ref.wim is never touched.
$ErrorActionPreference = 'Stop'
$vhd = 'D:\home-lab\vms\images.vhdx'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path

$disk = Mount-VHD -Path $vhd -Passthru | Get-Disk
try {
    $part = $disk | Get-Partition | Where-Object Type -eq 'Basic' | Select-Object -First 1
    if (-not $part.DriveLetter) { $part | Add-PartitionAccessPath -AssignDriveLetter; $part = $part | Get-Partition }
    $dest = "$($part.DriveLetter):\Deploy"
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item "$dir\37-pc01-partition-uefi.txt", "$dir\39-deploy-ref-wim.cmd" $dest -Force
    Get-ChildItem "$($part.DriveLetter):\", $dest | Format-Table FullName, @{n='MB';e={[math]::Round($_.Length/1MB)}}
}
finally {
    Dismount-VHD -Path $vhd
}
"images.vhdx detached from the host again. Next: .\32-boot-from-dvd.ps1 PC01"
