# 44 - First contact with CM01 over PowerShell remoting (WinRM) from the host: wait for it to finish first boot, delete the
# unattend.xml (it holds the local admin password in plain text), then join lab.dupnet.internal and restart.
# Run on the HOST in a normal (non-admin) PowerShell, after 43. Uses the two DPAPI credential files 43 stored; prints no passwords.
# Same as: signing in to CM01's console, deleting C:\Windows\Panther\unattend.xml, then Settings > System > About > Domain join.
# Why remoting works with no setup inside CM01: Windows Server has PowerShell remoting on by default, its firewall rule allows the
# local subnet (the host is 192.168.100.1 on LabNAT), and the built-in Administrator isn't filtered by remote UAC.
$ErrorActionPreference = 'Stop'
$ip    = '192.168.100.11'
$sec   = Join-Path $env:USERPROFILE '.homelab'
$local = Import-Clixml "$sec\cm01-local-admin.xml"
$lab   = Import-Clixml "$sec\lab-admin.xml"

"Waiting for CM01's WinRM at $ip ..."
$deadline = (Get-Date).AddMinutes(25)
while (-not (Test-WSMan -ComputerName $ip -ErrorAction SilentlyContinue)) {
    if ((Get-Date) -gt $deadline) { throw "CM01 didn't answer on WinRM within 25 min. Check its console in Hyper-V Manager." }
    Start-Sleep -Seconds 15
}
"CM01 is up."

Invoke-Command -ComputerName $ip -Credential $local -ScriptBlock {
    Remove-Item C:\Windows\Panther\unattend.xml -Force -ErrorAction SilentlyContinue
    "Name: $env:COMPUTERNAME   unattend.xml gone: $(-not (Test-Path C:\Windows\Panther\unattend.xml))"
    Get-NetIPConfiguration | Where-Object IPv4DefaultGateway |
        Format-Table InterfaceAlias, @{n='IPv4';e={$_.IPv4Address.IPAddress}}, @{n='DNS';e={$_.DNSServer.ServerAddresses -join ','}} | Out-String
    (Get-CimInstance Win32_OperatingSystem).Caption
}

if ((Invoke-Command -ComputerName $ip -Credential $local -ScriptBlock { (Get-CimInstance Win32_ComputerSystem).PartOfDomain }) -eq $true) {
    'CM01 is already in the domain.'
} else {
    # -Restart ends the remote session mid-call; that "error" is expected
    try { Invoke-Command -ComputerName $ip -Credential $local -ScriptBlock { Add-Computer -DomainName lab.dupnet.internal -Credential $using:lab -Restart -Force } }
    catch { "(session closed by the restart, expected: $($_.Exception.Message.Split([char]10)[0]))" }
    'Join sent; CM01 restarting.'
    Start-Sleep -Seconds 30
    $deadline = (Get-Date).AddMinutes(10)
    while (-not (Test-WSMan -ComputerName $ip -ErrorAction SilentlyContinue)) { if ((Get-Date) -gt $deadline) { throw 'CM01 did not come back after the restart.' }; Start-Sleep -Seconds 10 }
}
Invoke-Command -ComputerName $ip -Credential $lab -ScriptBlock {
    $cs = Get-CimInstance Win32_ComputerSystem
    "Signed in remotely as: $(whoami)   Domain: $($cs.Domain)   PartOfDomain: $($cs.PartOfDomain)"
}
