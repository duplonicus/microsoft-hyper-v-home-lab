# 46 - SQL Server 2022 (Evaluation) on CM01 for the ConfigMgr site database, unattended, from the HOST over remoting.
# Run on the HOST in a normal PowerShell, after 45. ~15-25 min.
# Same as: running SQL2022-SSEI-Eval.exe > Download Media (ISO), mounting it, setup.exe > New installation > Database Engine
# Services only > default instance > service account Local System > collation SQL_Latin1_General_CP1_CI_AS > add LAB\Administrator
# as sysadmin > max server memory 8 GB.
# ConfigMgr's SQL rules (Learn "Supported configurations for SQL Server", "Support for SQL Server versions", read 2026-11-05):
#   SQL 2022 supported (from ConfigMgr 2303); only Database Engine Services needed; collation MUST be SQL_Latin1_General_CP1_CI_AS;
#   Local System service account is fine (ConfigMgr registers the SPN itself); limit SQL to 50-80% of RAM on a shared box.
#   Edition: Learn's table lists Standard/Enterprise; Evaluation (= Enterprise features, 180 days) is NOT on the list. Lab-only choice.
# SQL setup switches: Learn "Install SQL Server from the command prompt". The bootstrapper's download switches
# (/ACTION=Download /MEDIAPATH /MEDIATYPE=ISO /QUIET) are NOT on a Microsoft page I could find; if they fail, download the ISO by hand.
$ErrorActionPreference = 'Stop'
$lab = Import-Clixml (Join-Path $env:USERPROFILE '.homelab\lab-admin.xml')

# ISO source (2026-11-06): the bootstrapper's download switches hung on CM01 for 43 min (plain HTTP from the lab VMs is broken) and
# crashed on the host (exit 0xE0434352, a .NET crash). So download the ISO by hand on the host: run
# D:\home-lab\sql\SQL2022-SSEI-Eval.exe > Download Media > English, ISO > D:\home-lab\sql\media. This copies it into CM01.
# The Evaluation Center's download button (fwlink 2215202) served a RETIRED bootstrapper (16.2211.5693.3): "This version of the installer
# is no longer supported". The link in that error (fwlink 2162123) gives the current one (16.2607.0.1, signed Microsoft).
$hostIso = Get-ChildItem 'D:\home-lab\sql\media\*.iso' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($hostIso) {
    $s = New-PSSession -ComputerName 192.168.100.11 -Credential $lab
    Invoke-Command -Session $s { New-Item -ItemType Directory -Force C:\Install\SQLMedia | Out-Null }
    if (-not (Invoke-Command -Session $s { Test-Path "C:\Install\SQLMedia\$($using:hostIso.Name)" })) {
        "Copying $($hostIso.Name) ($([math]::Round($hostIso.Length/1GB,2)) GB) to CM01..."
        Copy-Item -ToSession $s -Path $hostIso.FullName -Destination 'C:\Install\SQLMedia\' -Force
    }
    Remove-PSSession $s
}

Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    $ErrorActionPreference = 'Stop'
    if (Get-Service MSSQLSERVER -ErrorAction SilentlyContinue) { 'SQL Server already installed:'; Get-Service MSSQLSERVER; return }
    $in = 'C:\Install'
    "1. Download the SQL 2022 Evaluation ISO with the bootstrapper"
    if (-not (Get-ChildItem "$in\SQLMedia\*.iso" -ErrorAction SilentlyContinue)) {
        $p = Start-Process "$in\SQL2022-SSEI-Eval.exe" -ArgumentList '/ACTION=Download', "/MEDIAPATH=$in\SQLMedia", '/MEDIATYPE=ISO', '/QUIET' -Wait -PassThru
        "  bootstrapper exit code: $($p.ExitCode)"
    }
    $iso = Get-ChildItem "$in\SQLMedia\*.iso" | Select-Object -First 1
    if (-not $iso) { throw 'No SQL ISO in C:\Install\SQLMedia (download switches failed?).' }
    "  ISO: $($iso.Name) ($([math]::Round($iso.Length/1GB,2)) GB)"

    "2. Install the Database Engine"
    $d = (Mount-DiskImage -ImagePath $iso.FullName -PassThru | Get-Volume).DriveLetter
    # Runs as a SCHEDULED TASK logged on as LAB\Administrator, not straight in this remoting session: first run (2026-11-06) failed
    # in 23 s with "There was an error generating the XML document"; Detail.txt's inner exception: CryptographicException "The
    # computer must be trusted for delegation and the current user account must be configured to allow delegation" (0x80090345).
    # SQL setup uses DPAPI, which needs a real logon with a loaded profile; a WinRM network logon doesn't have one.
    $sqlArgs = "/Q /ACTION=Install /FEATURES=SQLENGINE /INSTANCENAME=MSSQLSERVER /SQLSVCACCOUNT=""NT AUTHORITY\SYSTEM"" " +
               "/SQLSYSADMINACCOUNTS=""LAB\Administrator"" ""BUILTIN\Administrators"" /SQLCOLLATION=SQL_Latin1_General_CP1_CI_AS " +
               "/SQLMAXMEMORY=8192 /TCPENABLED=1 /UpdateEnabled=False /IACCEPTSQLSERVERLICENSETERMS /SUPPRESSPRIVACYSTATEMENTNOTICE"
    @"
`$p = Start-Process '${d}:\setup.exe' -ArgumentList '$($sqlArgs -replace "'", "''")' -Wait -PassThru
`$p.ExitCode | Set-Content 'C:\Install\logs\sqlsetup.exit'
"@ | Set-Content C:\Install\run-sqlsetup.ps1 -Encoding ascii
    Remove-Item C:\Install\logs\sqlsetup.exit -ErrorAction SilentlyContinue
    $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Install\run-sqlsetup.ps1'
    Register-ScheduledTask -TaskName 'Lab-SQLSetup' -Action $a -User 'LAB\Administrator' -Password ($using:lab).GetNetworkCredential().Password -RunLevel Highest -Force | Out-Null
    Start-ScheduledTask -TaskName 'Lab-SQLSetup'
    "  SQL setup started as a scheduled task; waiting (checks every 30 s)..."
    $t = (Get-Date).AddMinutes(45)
    while (-not (Test-Path C:\Install\logs\sqlsetup.exit) -and (Get-Date) -lt $t) { Start-Sleep 30 }
    Unregister-ScheduledTask -TaskName 'Lab-SQLSetup' -Confirm:$false
    $p = [pscustomobject]@{ ExitCode = [int](Get-Content C:\Install\logs\sqlsetup.exit -ErrorAction SilentlyContinue) }
    "  SQL setup exit code: $($p.ExitCode)  (0 = success, 3010 = success + restart needed)"
    Dismount-DiskImage -ImagePath $iso.FullName | Out-Null
    $summary = Get-ChildItem 'C:\Program Files\Microsoft SQL Server\*\Setup Bootstrap\Log\Summary.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($summary) { Get-Content $summary.FullName -TotalCount 12 }
    if ($p.ExitCode -notin 0, 3010) { throw "SQL setup failed ($($p.ExitCode)); see Summary.txt above." }

    "3. Check"
    Get-Service MSSQLSERVER | Format-Table Name, Status, StartType -AutoSize | Out-String
    $q = "SELECT SERVERPROPERTY('ProductVersion') AS Version, SERVERPROPERTY('Edition') AS Edition, SERVERPROPERTY('Collation') AS Collation;"
    $cn = New-Object System.Data.SqlClient.SqlConnection 'Server=localhost;Integrated Security=True;TrustServerCertificate=True'
    $cn.Open(); $cmd = $cn.CreateCommand(); $cmd.CommandText = $q; $r = $cmd.ExecuteReader(); $r.Read() | Out-Null
    "  Version $($r['Version'])   Edition $($r['Edition'])   Collation $($r['Collation'])"; $cn.Close()
}
