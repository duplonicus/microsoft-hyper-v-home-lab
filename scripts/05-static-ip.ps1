# 05 - fixed IP for DC01. Run INSIDE DC01 in an Administrator PowerShell,
# after its network adapter is on the LabNAT switch (Hyper-V Manager > DC01 Settings > Network Adapter).
# DNS points at public resolvers for now: WinNAT does not answer DNS. Promotion to DC changes it later.
# Next: install AD DS and promote.
$ErrorActionPreference = 'Stop'

$nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1

# Drop the old DHCP address and gateway before setting the fixed one
Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
Remove-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix 0.0.0.0/0 -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 192.168.100.10 -PrefixLength 24 -DefaultGateway 192.168.100.1 | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses 1.1.1.1, 8.8.8.8

# The 169.254 address DHCP fell back to on LabNAT (nothing there hands out addresses)
Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 |
    Where-Object IPAddress -like '169.254.*' | Remove-NetIPAddress -Confirm:$false

# A new address is not usable until Windows has checked nobody else has it.
# Testing straight away failed on the first run (2026-10-28) and passed a minute later.
$deadline = (Get-Date).AddSeconds(30)
while ((Get-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 192.168.100.10).AddressState -ne 'Preferred' -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
}

Get-NetIPConfiguration -InterfaceIndex $nic.ifIndex
Test-NetConnection microsoft.com -Port 443 | Select-Object ComputerName, RemoteAddress, TcpTestSucceeded
