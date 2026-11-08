# 18 - check DC01 is ready for the Microsoft Entra Cloud Sync agent. Run INSIDE DC01 as LAB\Administrator
# in an Administrator PowerShell. Read-only except the TLS 1.2 keys, which it sets only if they're missing
# (then a restart is needed before installing). Requirements from Microsoft Learn,
# "Prerequisites for Microsoft Entra Cloud Sync" (checked 2026-10-28). Next: 18a-install-cloud-sync-agent.ps1.
$ErrorActionPreference = 'Stop'

$os = Get-CimInstance Win32_OperatingSystem
"Windows:     $($os.Caption)  (2025 or 2022 recommended; Server Core not supported)"
"RAM:         $([math]::Round($os.TotalVisibleMemorySize / 1MB, 1)) GB visible now  (4 GB minimum; dynamic memory can show less)"

# .NET Framework 4.7.1 or later = release 461308+
$release = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Release
".NET:        release $release  (need 461308+)  $(if ($release -ge 461308) { 'OK' } else { 'TOO OLD' })"

"Exec policy: $(Get-ExecutionPolicy -Scope LocalMachine)  (must be Undefined or RemoteSigned)"
"VaultSvc:    $((Get-Service VaultSvc).StartType)  (must not be Disabled)"

$schema = (Get-ADRootDSE).schemaNamingContext
$attr = Get-ADObject -SearchBase $schema -Filter "lDAPDisplayName -eq 'msDS-ExternalDirectoryObjectId'"
"Schema:      msDS-ExternalDirectoryObjectId $(if ($attr) { 'present' } else { 'MISSING' })"

# TLS 1.2 on for the agent (the keys from the Learn page)
$tls = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'
$changed = $false
foreach ($side in 'Client', 'Server') {
    $key = "$tls\$side"
    $p = Get-ItemProperty $key -ErrorAction SilentlyContinue
    if (-not $p -or $p.Enabled -ne 1 -or $p.DisabledByDefault -ne 0) {
        New-Item $key -Force | Out-Null
        Set-ItemProperty $key -Name Enabled -Value 1 -Type DWord
        Set-ItemProperty $key -Name DisabledByDefault -Value 0 -Type DWord
        $changed = $true
    }
}
$net = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
if ((Get-ItemProperty $net -ErrorAction SilentlyContinue).SchUseStrongCrypto -ne 1) {
    Set-ItemProperty $net -Name SchUseStrongCrypto -Value 1 -Type DWord
    $changed = $true
}
"TLS 1.2:     $(if ($changed) { 'keys were missing and are now set: RESTART DC01 before installing the agent' } else { 'already set' })"
