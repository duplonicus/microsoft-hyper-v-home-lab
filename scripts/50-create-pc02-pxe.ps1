# 50 - PC02: a blank Gen 2 VM that boots from the NETWORK, then presses F12 so ConfigMgr's PXE answer starts the task sequence.
# The point: nobody touches the disk; ConfigMgr partitions it, applies ref.wim, joins the domain (svc-cm-join, into
# OU=Workstations) and installs the ConfigMgr client.
# Run on the HOST in an ELEVATED PowerShell (Claude launches it with a UAC prompt), after 49 (PXE DP + deployment ready).
# Same as: Hyper-V Manager > New VM (Gen 2, 4 GB, LabNAT, new 64 GB disk, no ISO), Settings > Security > TPM, Firmware > Network
# Adapter first; Start; press F12 at "Press F12 for network service boot"; pick "Deploy Win11-Ref-v1" in the task sequence wizard.
# F12: the deployment is Available (not Required), so PXE waits for F12 (Learn "Use PXE to deploy Windows over the network").
# Keys are typed with Hyper-V's WMI virtual keyboard (Msvm_Keyboard.TypeKey, VK_F12 = 0x7B), like 32-boot-from-dvd.
# -NoStart: build PC02 and stop there (you start it and press F12 yourself). Also starts DC01 (DHCP) and CM01 (PXE) if off.
param([switch]$NoStart)
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'claude-elevated.log'
Start-Transcript -Path $log -Force | Out-Null
try {
    $vms = 'D:\home-lab\vms'
    if (Get-VM -Name PC02 -ErrorAction SilentlyContinue) {
        if ((Get-VM PC02).State -ne 'Off') { Stop-VM -Name PC02 -TurnOff -Force }
        'PC02 exists; reusing it (powered off).'
    } else {
        New-VM -Name PC02 -Generation 2 -MemoryStartupBytes 4GB -NewVHDPath "$vms\PC02.vhdx" -NewVHDSizeBytes 64GB -SwitchName 'LabNAT' | Out-Null
        Set-VMMemory    -VMName PC02 -DynamicMemoryEnabled $false
        Set-VMProcessor -VMName PC02 -Count 2
        Set-VM          -Name PC02 -AutomaticCheckpointsEnabled $false
        Set-VMKeyProtector -VMName PC02 -NewLocalKeyProtector
        Enable-VMTPM       -VMName PC02
        'PC02 created: Gen 2, 4 GB, 2 vCPU, 64 GB blank disk, vTPM, LabNAT.'
    }
    $nic = Get-VMNetworkAdapter -VMName PC02
    Set-VMFirmware -VMName PC02 -FirstBootDevice $nic
    "MAC: $($nic.MacAddress)   (ConfigMgr will list PC02 under this MAC once it PXE-boots)"
    (Get-VMFirmware -VMName PC02).BootOrder | Format-Table BootType, Description -AutoSize | Out-String

    foreach ($n in 'DC01','CM01') { if ((Get-VM $n).State -ne 'Running') { Start-VM $n; "$n was off; started it." } }
    Get-VM | Format-Table Name, State, CPUUsage, @{n='MemGB';e={[math]::Round($_.MemoryAssigned/1GB,1)}} -AutoSize | Out-String
    if ($NoStart) { 'PC02 is ready and OFF (-NoStart). Next: Hyper-V Manager > PC02 > Connect > Start, press F12 at the PXE prompt.'; return }

    Start-VM -Name PC02
    $cs = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_ComputerSystem -Filter "ElementName='PC02'"
    $kb = $null
    for ($i = 0; -not $kb -and $i -lt 20; $i++) { $kb = Get-CimAssociatedInstance -InputObject $cs -ResultClassName Msvm_Keyboard -ErrorAction SilentlyContinue; if (-not $kb) { Start-Sleep -Milliseconds 250 } }
    # PXE (DHCP + ConfigMgr's answer) takes several seconds before the F12 prompt, which then waits only briefly: press for 60 s.
    'Pressing F12 in PC02 for 60 s...'
    $end = (Get-Date).AddSeconds(60); $sent = 0
    while ((Get-Date) -lt $end) {
        try { Invoke-CimMethod -InputObject $kb -MethodName TypeKey -Arguments @{ keyCode = [uint32]0x7B } | Out-Null; $sent++ } catch { }
        Start-Sleep -Milliseconds 700
    }
    "Sent $sent F12 presses. Watch PC02's window: WinPE loads, then the task sequence wizard (click Next, pick 'Deploy Win11-Ref-v1')."
}
catch { "FAILED: $($_.Exception.Message)"; $_.ScriptStackTrace }
finally { Stop-Transcript | Out-Null }
