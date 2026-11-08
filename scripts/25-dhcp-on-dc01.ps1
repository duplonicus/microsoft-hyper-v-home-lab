# 25 - DHCP server role on DC01, so new VMs on LabNAT get an address, gateway and the lab DNS by themselves.
# Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Same as Server Manager > Add Roles > DHCP Server, then the DHCP console: Authorize, New Scope
# (192.168.100.100-199, router .1, DNS .10, domain lab.dupnet.internal), and the "Complete DHCP configuration" flag.
# Why: LabNAT is an internal switch with no DHCP (part 1 gave DC01 a static IP), so REF01/PC01/PC02 would get 169.254.x.x.
# Commands from Microsoft Learn: "Install and configure DHCP Server on Windows Server" (checked 2026-11-05).
# Safe to re-run: an existing scope is left alone.
$ErrorActionPreference = 'Stop'

Install-WindowsFeature DHCP -IncludeManagementTools | Select-Object Success, RestartNeeded, ExitCode

# Local groups "DHCP Administrators" / "DHCP Users", then restart the service so it picks them up
netsh dhcp add securitygroups
Restart-Service dhcpserver

# Authorize in AD (an unauthorized DHCP server in a domain won't lease anything)
$fqdn = "$env:COMPUTERNAME.$((Get-ADDomain).DNSRoot)"
if (-not (Get-DhcpServerInDC | Where-Object IPAddress -eq '192.168.100.10')) {
    Add-DhcpServerInDC -DnsName $fqdn -IPAddress 192.168.100.10
}

if (-not (Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object ScopeId -eq '192.168.100.0')) {
    Add-DhcpServerv4Scope -Name 'LabNAT clients' -StartRange 192.168.100.100 -EndRange 192.168.100.199 `
        -SubnetMask 255.255.255.0 -LeaseDuration 8.00:00:00 -State Active
}
# 3 = router (the host's LabNAT gateway), 6 = DNS (DC01 itself), 15 = DNS domain name
Set-DhcpServerv4OptionValue -ScopeId 192.168.100.0 -OptionId 3 -Value 192.168.100.1
Set-DhcpServerv4OptionValue -ScopeId 192.168.100.0 -OptionId 6 -Value 192.168.100.10
Set-DhcpServerv4OptionValue -ScopeId 192.168.100.0 -OptionId 15 -Value (Get-ADDomain).DNSRoot

# Tell Server Manager the post-install wizard is done (clears its yellow flag)
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2

Get-DhcpServerInDC
Get-DhcpServerv4Scope | Format-Table ScopeId, Name, StartRange, EndRange, State
Get-DhcpServerv4OptionValue -ScopeId 192.168.100.0 | Format-Table OptionId, Name, Value
# DNS for clients: can DC01's DNS server resolve the internet? (PC01/PC02 will use it for everything)
Resolve-DnsName microsoft.com -Server 127.0.0.1 -Type A | Select-Object -First 2 Name, IPAddress
