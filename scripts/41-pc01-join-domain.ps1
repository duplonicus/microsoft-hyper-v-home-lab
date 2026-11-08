# 41 - Join PC01 to lab.dupnet.internal, named PC01, straight into the Workstations OU. Run INSIDE PC01 (after OOBE, signed in
# as the local account made there) in an Administrator PowerShell. Get it there with 26c-push-scripts-to-vm.ps1 PC01 (host).
# Same as: Settings > System > About > Rename this PC, then Settings > Accounts > Access work or school > Join this device to a
# local Active Directory domain; then ADUC on DC01: move the computer from "Computers" to Workstations.
# -OUPath puts the computer object in the right OU at join time, so there's no "move it later" step (and no PC sitting in the
# default Computers container, where OU-linked GPOs don't apply). Prompts for LAB\Administrator's password; nothing stored.
$ErrorActionPreference = 'Stop'

# 1. Network sanity: address from DC01's DHCP, DNS = DC01 (domain join finds the DC through DNS)
Get-NetIPConfiguration | Where-Object IPv4DefaultGateway |
    Format-Table InterfaceAlias, @{n='IPv4';e={$_.IPv4Address.IPAddress}}, @{n='DNS';e={$_.DNSServer.ServerAddresses -join ','}}
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.lab.dupnet.internal | Select-Object -First 1 Name, NameTarget, Port

# 2. Rename + join + OU in one go, then restart
$cred = Get-Credential -UserName 'LAB\Administrator' -Message 'Domain admin password (to create PC01''s computer account)'
$join = @{ DomainName = 'lab.dupnet.internal'; OUPath = 'OU=Workstations,DC=lab,DC=dupnet,DC=internal'; Credential = $cred; Restart = $true }
# -NewName only if the name differs: Add-Computer refuses the whole join when the new name equals the current one
# (first run 2026-11-05: "name is same as current name": the PC was already called PC01, how is NOT known)
if ($env:COMPUTERNAME -ne 'PC01') { $join.NewName = 'PC01' }
"Current name: $env:COMPUTERNAME"
Add-Computer @join
