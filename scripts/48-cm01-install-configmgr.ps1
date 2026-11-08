# 48 - Install the ConfigMgr 2509 primary site on CM01, unattended (setup.exe /SCRIPT), started from the HOST.
# Run on the HOST in a normal PowerShell, after 46 (SQL) and 47 (AD prep). Setup itself takes ~30-60 min; this script waits.
# Same as: on CM01, C:\Install\CM\splash.hta > Install > "Install a Configuration Manager primary site" > Evaluation > download
# prerequisite files > site code LAB, site name "Lab Primary Site" > SQL CM01 / CM_LAB > management point + distribution point on CM01
# over HTTP > service connection point online > no CEIP.
# Settings: Learn "Command-line options for setup" / "Unattended setup script file" (example keys, ProductID=Eval, JoinCEIP=0 required,
# [SABranchOptions]); prerequisite files: Learn "Setup Downloader" (setupdl.exe /NOUI <folder>, after ODBC is installed). Read 2026-11-05.
# Why a scheduled task as LAB\Administrator instead of running setup.exe straight over remoting: setup reads Active Directory
# (schema, System Management container) and a remoting session can't pass the password on to DC01 (double hop). A scheduled task
# runs as a real logon of LAB\Administrator on CM01. The password goes from the DPAPI file straight into Register-ScheduledTask.
$ErrorActionPreference = 'Stop'
$ip  = '192.168.100.11'
$lab = Import-Clixml (Join-Path $env:USERPROFILE '.homelab\lab-admin.xml')

Invoke-Command -ComputerName $ip -Credential $lab -ScriptBlock {
    $ErrorActionPreference = 'Stop'
    $in = 'C:\Install'; $bin = "$in\CM\SMSSETUP\BIN\X64"
    # A failed setup can leave HKLM\SOFTWARE\Microsoft\SMS\Setup behind (2026-11-06), so check for the site's main service instead
    if (Get-Service SMS_EXECUTIVE -ErrorAction SilentlyContinue) { 'ConfigMgr already installed (SMS_EXECUTIVE exists).'; return }

    "1. Firewall: SQL (1433) and SQL Service Broker (4022) for the site"
    foreach ($r in @(@{n='SQL Server 1433'; p=1433}, @{n='SQL Service Broker 4022'; p=4022})) {
        if (-not (Get-NetFirewallRule -DisplayName $r.n -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $r.n -Direction Inbound -Protocol TCP -LocalPort $r.p -Action Allow | Out-Null }
    }

    "2. Prerequisite files (setupdl.exe)"
    if (-not (Get-ChildItem "$in\CMPrereqs" -ErrorAction SilentlyContinue)) {
        $p = Start-Process "$bin\setupdl.exe" -ArgumentList '/NOUI', "$in\CMPrereqs" -Wait -PassThru
        "  setupdl exit code: $($p.ExitCode); files: $((Get-ChildItem "$in\CMPrereqs" -Recurse -File).Count)"
    }

    "3. setup.ini"
    $fqdn = "$env:COMPUTERNAME.$((Get-CimInstance Win32_ComputerSystem).Domain)"
    @"
[Identification]
Action=InstallPrimarySite

[Options]
ProductID=Eval
SiteCode=LAB
SiteName=Lab Primary Site
SMSInstallDir=C:\Program Files\Microsoft Configuration Manager
SDKServer=$fqdn
PrerequisiteComp=1
PrerequisitePath=$in\CMPrereqs
AdminConsole=1
JoinCEIP=0
ManagementPoint=$fqdn
ManagementPointProtocol=HTTP
DistributionPoint=$fqdn
DistributionPointProtocol=HTTP
DistributionPointInstallIIS=1
RoleCommunicationProtocol=HTTPorHTTPS
ClientsUsePKICertificate=0
MobileDeviceLanguage=0

[SQLConfigOptions]
SQLServerName=$fqdn
SQLServerPort=1433
DatabaseName=CM_LAB
SQLSSBPort=4022

[CloudConnectorOptions]
CloudConnector=1
CloudConnectorServer=$fqdn
UseProxy=0

[SABranchOptions]
SAActive=1
CurrentBranch=1

[HierarchyExpansionOption]
"@ | Set-Content "$in\setup.ini" -Encoding ascii

    "4. Start setup as a scheduled task running as LAB\Administrator"
    @"
`$p = Start-Process '$bin\setup.exe' -ArgumentList '/script', '$in\setup.ini', '/NOUSERINPUT' -Wait -PassThru
`$p.ExitCode | Set-Content '$in\logs\cmsetup.exit'
"@ | Set-Content "$in\run-cmsetup.ps1" -Encoding ascii
    Remove-Item "$in\logs\cmsetup.exit" -ErrorAction SilentlyContinue
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File $in\run-cmsetup.ps1"
    Register-ScheduledTask -TaskName 'Lab-CMSetup' -Action $action -User 'LAB\Administrator' `
        -Password ($using:lab).GetNetworkCredential().Password -RunLevel Highest -Force | Out-Null
    Start-ScheduledTask -TaskName 'Lab-CMSetup'
    '  started.'
}

"5. Waiting for setup (checks every 60 s; shows the last line of C:\ConfigMgrSetup.log)"
$deadline = (Get-Date).AddMinutes(150)
do {
    Start-Sleep -Seconds 60
    $st = Invoke-Command -ComputerName $ip -Credential $lab -ScriptBlock {
        [pscustomobject]@{
            Exit = Get-Content 'C:\Install\logs\cmsetup.exit' -ErrorAction SilentlyContinue
            Running = [bool](Get-Process setup, setupwpf -ErrorAction SilentlyContinue)
            Last = (Get-Content 'C:\ConfigMgrSetup.log' -Tail 1 -ErrorAction SilentlyContinue) -replace '\s+', ' '
        }
    }
    "  $(Get-Date -Format t)  $($st.Last.Substring(0, [math]::Min(160, $st.Last.Length)))"
    # Done = the exit-code file has a value AND setup's processes are gone. (First version tested `$st.Exit -ne $null`: a missing file
    # comes back over remoting as an empty string, not $null, so the loop quit after 1 minute while setup was still running, 2026-11-06.)
} until (([string]$st.Exit -ne '' -and -not $st.Running) -or (Get-Date) -gt $deadline)

Invoke-Command -ComputerName $ip -Credential $lab -ScriptBlock {
    Unregister-ScheduledTask -TaskName 'Lab-CMSetup' -Confirm:$false -ErrorAction SilentlyContinue
    "setup.exe exit code: $(Get-Content 'C:\Install\logs\cmsetup.exit' -ErrorAction SilentlyContinue)"
    "--- ConfigMgrPrereq.log errors (if any) ---"
    Select-String -Path 'C:\ConfigMgrPrereq.log' -Pattern 'ERROR' -ErrorAction SilentlyContinue | Select-Object -Last 10 | ForEach-Object { $_.Line }
    "--- ConfigMgrSetup.log, last 8 lines ---"
    Get-Content 'C:\ConfigMgrSetup.log' -Tail 8 -ErrorAction SilentlyContinue
    "Site installed (SMS_EXECUTIVE service): $([bool](Get-Service SMS_EXECUTIVE -ErrorAction SilentlyContinue))"
}
