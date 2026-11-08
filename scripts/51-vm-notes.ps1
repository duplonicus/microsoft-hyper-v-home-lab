# 51 - Label each lab VM with how it was built, in Hyper-V's Notes field (Settings > Management > Name > Notes).
# Why Notes and not the VM name: 16 scripts find VMs by name (Get-VM PC02, vmconnect localhost PC02), so names stay short and plain.
# Notes show in Hyper-V Manager's bottom panel (Summary tab) when a VM is selected. Safe while VMs are running.
# Run on the HOST in an ELEVATED PowerShell. Re-run any time to overwrite the notes.
$notes = [ordered]@{
    DC01  = "Domain controller for lab.dupnet.internal: AD DS, DNS, DHCP (192.168.100.10). Built BY HAND; scripts 01a-25 are the PowerShell record."
    REF01 = "Golden image: Windows 11 built by hand in Audit Mode, sysprepped, captured to ref.wim (Win11-Ref-v1). Scripts 26-35."
    PC01  = "Deployed BY HAND from ref.wim: WinPE, diskpart, DISM apply, bcdboot, domain join. Scripts 36-42."
    CM01  = "ConfigMgr 2509 primary site LAB (MP + DP + PXE), SQL 2022 Eval (192.168.100.11). Built with scripts 43-49."
    PC02  = "Deployed by CONFIGMGR over PXE as an unknown computer: task sequence 'Deploy Win11-Ref-v1', name from OSDComputerName. Scripts 50-50g."
}
foreach ($vm in $notes.Keys) {
    if (Get-VM -Name $vm -ErrorAction SilentlyContinue) { Set-VM -Name $vm -Notes $notes[$vm] } else { "skipped $vm (no such VM)" }
}
Get-VM | Format-Table Name, State, Notes -AutoSize -Wrap
