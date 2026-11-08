# 08 - check DC01 after the promotion. Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Read-only: changes nothing.

# The domain and this DC
Get-ADDomain | Format-List DNSRoot, NetBIOSName, DomainMode, PDCEmulator
Get-ADDomainController | Format-List HostName, IPv4Address, IsGlobalCatalog

# DC01 should now ask itself for DNS (the promotion replaces 1.1.1.1 / 8.8.8.8)
Get-DnsClientServerAddress -InterfaceAlias Ethernet -AddressFamily IPv4 | Format-Table InterfaceAlias, ServerAddresses

# The records clients use to find a domain controller, then an internet name through DC01's own DNS
Resolve-DnsName _ldap._tcp.dc._msdcs.lab.dupnet.internal -Type SRV | Format-Table Name, NameTarget, Port
Resolve-DnsName microsoft.com -Type A | Select-Object -First 1 Name, IPAddress

# Microsoft's DC health check; /q prints only failures, so no output means healthy
dcdiag /q
