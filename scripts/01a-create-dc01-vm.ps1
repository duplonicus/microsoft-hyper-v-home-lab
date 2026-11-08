# 01a - Hyper-V default folders + the DC01 VM. Run on the HOST in an Administrator PowerShell.
# Same as Hyper-V Manager > Hyper-V Settings (both default paths), then New > Virtual Machine with:
# Gen 2, 4096 MB dynamic memory, 80 GB dynamically expanding disk, Default Switch, the Server 2025 eval ISO.
# Then VM Settings > Processor > 2. DC01 was built by hand on 2026-10-26/27; this script is the record, not what ran.
# Next: start DC01, boot from the DVD (click inside the console and press a key straight away), install Windows Server.
$ErrorActionPreference = 'Stop'

$Root = 'D:\home-lab\vms'
$Iso  = Get-ChildItem 'D:\home-lab\iso\*SERVER_EVAL*.iso' | Select-Object -First 1
if (-not $Iso) { throw 'No Windows Server eval ISO in D:\home-lab\iso.' }

# Keep VMs and disks off C:
Set-VMHost -VirtualMachinePath $Root -VirtualHardDiskPath $Root

if (Get-VM -Name DC01 -ErrorAction SilentlyContinue) { throw 'A VM called DC01 already exists.' }

New-VM -Name DC01 -Generation 2 -MemoryStartupBytes 4GB `
    -NewVHDPath "$Root\DC01.vhdx" -NewVHDSizeBytes 80GB -SwitchName 'Default Switch' | Out-Null
Set-VMMemory -VMName DC01 -DynamicMemoryEnabled $true
Set-VMProcessor -VMName DC01 -Count 2

# Boot from the ISO first; Gen 2 means UEFI + Secure Boot, which Server 2025 expects
$dvd = Add-VMDvdDrive -VMName DC01 -Path $Iso.FullName -Passthru
Set-VMFirmware -VMName DC01 -FirstBootDevice $dvd

Get-VM DC01 | Format-List Name, Generation, MemoryStartup, DynamicMemoryEnabled, ProcessorCount, Path
