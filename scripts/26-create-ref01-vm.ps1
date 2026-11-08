# 26 - REF01, the reference (golden image) VM, plus a second disk images.vhdx that will hold the captured .wim.
# Run on the HOST in an Administrator PowerShell (<path to this repo>\scripts\\, -ExecutionPolicy Bypass).
# Same as Hyper-V Manager > New > Virtual Machine: Gen 2, 4096 MB, 64 GB dynamic disk, LabNAT, the Windows 11 Enterprise ISO;
# then Settings > Security > Enable Trusted Platform Module, Processor > 2, SCSI Controller > Hard Drive > New (images.vhdx, 40 GB).
# Windows 11 needs Secure Boot + TPM 2.0; Gen 2 has Secure Boot on by default, the vTPM needs a key protector first.
# vTPM commands: Microsoft Learn Enable-VMTPM / Set-VMKeyProtector. Not safe to re-run (stops if REF01 exists).
$ErrorActionPreference = 'Stop'

$Root = 'D:\home-lab\vms'
$Iso  = Get-ChildItem 'D:\home-lab\iso\*.iso' | Where-Object Name -notmatch 'SERVER' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $Iso) { throw 'No Windows 11 ISO in D:\home-lab\iso (only the Server one?).' }
"Using ISO: $($Iso.Name)"

if (Get-VM -Name REF01 -ErrorAction SilentlyContinue) { throw 'A VM called REF01 already exists.' }

New-VM -Name REF01 -Generation 2 -MemoryStartupBytes 4GB `
    -NewVHDPath "$Root\REF01.vhdx" -NewVHDSizeBytes 64GB -SwitchName 'LabNAT' | Out-Null
Set-VMMemory    -VMName REF01 -DynamicMemoryEnabled $false   # Windows Setup is happier with fixed RAM
Set-VMProcessor -VMName REF01 -Count 2
Set-VM          -Name REF01 -AutomaticCheckpointsEnabled $false   # no surprise checkpoints; we make our own

# vTPM: needs a key protector before it can be enabled
Set-VMKeyProtector -VMName REF01 -NewLocalKeyProtector
Enable-VMTPM       -VMName REF01

# Second disk for the captured image (never capture a drive onto itself). Moves to PC01/PC02 later.
New-VHD -Path "$Root\images.vhdx" -SizeBytes 40GB -Dynamic | Out-Null
Add-VMHardDiskDrive -VMName REF01 -Path "$Root\images.vhdx"

# Boot from the ISO first
$dvd = Add-VMDvdDrive -VMName REF01 -Path $Iso.FullName -Passthru
Set-VMFirmware -VMName REF01 -FirstBootDevice $dvd

Get-VM REF01 | Format-List Name, Generation, MemoryStartup, ProcessorCount, Path
Get-VMSecurity REF01 | Format-List TpmEnabled
Get-VMFirmware REF01 | Format-List SecureBoot, SecureBootTemplate
Get-VMHardDiskDrive REF01 | Format-Table ControllerLocation, Path
