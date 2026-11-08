# 40 - PC01's first real boot: take out the ISO and the Images disk, then start it so the deployed Windows runs first-time setup.
# Run on the HOST in an Administrator PowerShell, after 39 finished inside PC01 and PC01 was shut down (wpeutil shutdown).
# Same as: PC01 Settings > DVD Drive > None, SCSI Controller > images.vhdx > Remove, then Start.
# Why: with the ISO gone, the only thing to boot is the Windows we just applied (bcdboot made it bootable). The Images disk is
# detached so it's free for the next deployment (PC02 / ConfigMgr) and doesn't show up as a stray drive in PC01.
# Expected: OOBE's "Is this the right country or region?" = the image works (Sysprep /oobe doing its job).
$ErrorActionPreference = 'Stop'

if ((Get-VM -Name PC01).State -ne 'Off') { throw 'PC01 is not off. If it is stuck at PXE: Stop-VM -Name PC01 -TurnOff -Force' }
Set-VMDvdDrive -VMName PC01 -Path $null
Get-VMHardDiskDrive -VMName PC01 | Where-Object Path -like '*images.vhdx' | Remove-VMHardDiskDrive

# Boot the disk FIRST. First run 2026-11-05 sat at "Start PXE over IPv4": with the DVD empty, the firmware tried the network
# adapter before the disk. Prefer the "Windows Boot Manager" entry bcdboot registered; fall back to the system disk itself.
$fw  = Get-VMFirmware -VMName PC01
"Boot order before:"; $fw.BootOrder | Format-Table BootType, Description -AutoSize | Out-String
$first = $fw.BootOrder | Where-Object Description -eq 'Windows Boot Manager' | Select-Object -First 1
if (-not $first) { $first = Get-VMHardDiskDrive -VMName PC01 -ControllerLocation 0 }
Set-VMFirmware -VMName PC01 -FirstBootDevice $first
"Boot order now:";    (Get-VMFirmware -VMName PC01).BootOrder | Format-Table BootType, Description -AutoSize | Out-String

Get-VMHardDiskDrive -VMName PC01 | Format-Table ControllerLocation, Path
Get-VMDvdDrive -VMName PC01 | Format-Table ControllerLocation, Path
Start-VM -Name PC01
"PC01 started. Open its window (Hyper-V Manager > Connect)."
