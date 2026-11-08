# 32 - start a VM and keep pressing Enter for a few seconds, so "Press any key to boot from CD or DVD" never gets missed.
# Run on the HOST in an Administrator PowerShell, from this scripts folder:   .\32-boot-from-dvd.ps1 REF01
# Open the VM's window (Hyper-V Manager > Connect) first if you want to watch it.
# How: Hyper-V's WMI API has a virtual keyboard per VM (Msvm_Keyboard) with a TypeKey method that takes a Windows virtual-key
# code (Learn "TypeKey method of the Msvm_Keyboard class", read 2026-11-05). 0x0D = Enter.
# The 8 s window covers the prompt (it shows ~2-5 s after power-on) and stops long before Windows Setup's first screen loads,
# so no stray key lands in Setup. First written 2026-11-05 for step 4; NOT tested before that first use.
# If it misses and Windows starts booting instead (OOBE's country/region screen): Turn Off the VM at once; for REF01 run
# scripts\33-ref01-restore-before-sysprep.ps1, Sysprep again (31), then this again.
param(
    [Parameter(Mandatory, Position = 0)][string]$VM,
    [int]$Seconds = 8
)
$ErrorActionPreference = 'Stop'

if ((Get-VM -Name $VM).State -ne 'Off') { throw "$VM is not off. Shut it down first." }

# Put the DVD FIRST in the boot order. First use on REF01 (2026-11-05) showed no "press any key" at all and went straight into
# OOBE: most likely Windows' install added "Windows Boot Manager" ahead of the DVD in the Gen 2 firmware order (not proven;
# the before/after order below shows it on the next run).
$dvd = Get-VMDvdDrive -VMName $VM | Select-Object -First 1
if (-not $dvd -or -not $dvd.Path) { throw "$VM has no DVD drive with an ISO in it." }
"Boot order before:"; (Get-VMFirmware -VMName $VM).BootOrder | Format-Table BootType, Description, Device -AutoSize | Out-String
Set-VMFirmware -VMName $VM -FirstBootDevice $dvd
"Boot order now:";    (Get-VMFirmware -VMName $VM).BootOrder | Format-Table BootType, Description, Device -AutoSize | Out-String

Start-VM -Name $VM

# The virtual keyboard only exists while the VM is running, so look it up after the start
$cs = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_ComputerSystem -Filter "ElementName='$VM'"
$kb = $null
for ($i = 0; -not $kb -and $i -lt 20; $i++) {
    $kb = Get-CimAssociatedInstance -InputObject $cs -ResultClassName Msvm_Keyboard -ErrorAction SilentlyContinue
    if (-not $kb) { Start-Sleep -Milliseconds 250 }
}
if (-not $kb) { throw "Couldn't find $VM's virtual keyboard. Press a key in the VM window yourself." }

"Pressing Enter in $VM for $Seconds s..."
$end = (Get-Date).AddSeconds($Seconds); $sent = 0
while ((Get-Date) -lt $end) {
    try { Invoke-CimMethod -InputObject $kb -MethodName TypeKey -Arguments @{ keyCode = [uint32]0x0D } | Out-Null; $sent++ } catch { }
    Start-Sleep -Milliseconds 300
}
"Sent $sent key presses. Within a minute you should be on Windows Setup's language screen. 'Getting ready' or a region screen = it missed."
