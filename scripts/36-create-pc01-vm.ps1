# 36 - PC01, the first deployment target: a blank Gen 2 VM with the Images disk (ref.wim) and the Windows ISO attached.
# Run on the HOST in an Administrator PowerShell, after 35 (checkpoints merged, images.vhdx detached from REF01). DC01 must be running
# (PC01 gets its address from DC01's DHCP).
# Same as Hyper-V Manager > New > Virtual Machine (Gen 2, 4096 MB, LabNAT, new 64 GB disk), Settings > Security > TPM,
# SCSI Controller > Hard Drive > images.vhdx, DVD Drive > the Windows 11 ISO.
# The ISO is only used to get a WinPE command prompt (Shift+F10); nothing gets installed from it. Boot it with 32-boot-from-dvd.ps1 PC01.
# Not safe to re-run (stops if PC01 exists).
$ErrorActionPreference = 'Stop'

$Root = 'D:\home-lab\vms'
$Iso  = Get-ChildItem 'D:\home-lab\iso\*.iso' | Where-Object Name -notmatch 'SERVER' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (Get-VM -Name PC01 -ErrorAction SilentlyContinue) { throw 'A VM called PC01 already exists.' }
if (Get-VMHardDiskDrive -VMName REF01 | Where-Object Path -like '*images.vhdx') { throw 'images.vhdx is still attached to REF01: run 35 first.' }

New-VM -Name PC01 -Generation 2 -MemoryStartupBytes 4GB `
    -NewVHDPath "$Root\PC01.vhdx" -NewVHDSizeBytes 64GB -SwitchName 'LabNAT' | Out-Null
Set-VMMemory    -VMName PC01 -DynamicMemoryEnabled $false
Set-VMProcessor -VMName PC01 -Count 2
Set-VM          -Name PC01 -AutomaticCheckpointsEnabled $false
Set-VMKeyProtector -VMName PC01 -NewLocalKeyProtector
Enable-VMTPM       -VMName PC01

# Images disk goes in at SCSI location 1, so the blank system disk stays location 0 (= "disk 0" in diskpart, normally)
Add-VMHardDiskDrive -VMName PC01 -Path "$Root\images.vhdx" -ControllerLocation 1
Add-VMDvdDrive      -VMName PC01 -Path $Iso.FullName

Get-VMHardDiskDrive -VMName PC01 | Format-Table ControllerLocation, Path
Get-VMDvdDrive -VMName PC01 | Format-Table ControllerLocation, Path
Get-VMSecurity PC01 | Format-List TpmEnabled
