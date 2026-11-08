# Step 0: check the Windows edition and turn on Hyper-V.
# PowerShell equivalent of: winver + "Turn Windows features on or off" -> Hyper-V.
# Safe to re-run: if Hyper-V is already on, it only reports that.
#
# Run in an ADMIN Windows PowerShell (Start -> type "powershell" -> Run as administrator):
#   powershell -ExecutionPolicy Bypass -File <path to this repo>\scripts\01-enable-hyper-v.ps1
# (-ExecutionPolicy Bypass because a script on a \\ path counts as "from the network" and gets blocked otherwise.)

#Requires -RunAsAdministrator

# 1. Edition. Hyper-V needs Pro or Enterprise; Home can't install it.
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "Windows edition: $($os.Caption)  (build $($os.BuildNumber))"
if ($os.Caption -match 'Home') {
    Write-Host "This is Windows Home: Hyper-V can't be installed. Stop here." -ForegroundColor Red
    return
}

# 2. Is the CPU ready? HypervisorPresent = True means a hypervisor is already running
#    (here it's WSL2's Virtual Machine Platform), so virtualization is on in the BIOS.
$cs = Get-CimInstance Win32_ComputerSystem
Write-Host "Hypervisor already running: $($cs.HypervisorPresent)"

# 3. Current state of the Hyper-V features (the parent and its sub-features).
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V* |
    Select-Object FeatureName, State | Format-Table -AutoSize

# 4. Turn it on if it isn't. -All also turns on the sub-features (Hyper-V Manager, PowerShell module).
#    -NoRestart so YOU decide when to reboot.
$hv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
if ($hv.State -eq 'Enabled') {
    Write-Host "Hyper-V is already enabled. Nothing to do." -ForegroundColor Green
} else {
    $result = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
    if ($result.RestartNeeded) {
        Write-Host "Hyper-V enabled. Restart Windows to finish (Restart-Computer when you're ready)." -ForegroundColor Yellow
    } else {
        Write-Host "Hyper-V enabled, no restart needed." -ForegroundColor Green
    }
}
