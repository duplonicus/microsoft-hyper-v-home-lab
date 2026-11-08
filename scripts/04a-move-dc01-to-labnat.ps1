# 04a - plug DC01's network adapter into the LabNAT switch. Run on the HOST in an Administrator PowerShell.
# Same as Hyper-V Manager > DC01 > Settings > Network Adapter > Virtual switch: LabNAT. Works while DC01 runs.
# DC01 has no internet until 05-static-ip.ps1 gives it an address (nothing on LabNAT hands them out).
# Next: 05-static-ip.ps1 inside DC01.
$ErrorActionPreference = 'Stop'

Connect-VMNetworkAdapter -VMName DC01 -SwitchName LabNAT
Get-VMNetworkAdapter -VMName DC01 | Format-Table VMName, SwitchName, Status
