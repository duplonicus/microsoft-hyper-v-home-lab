# 45 - ConfigMgr prerequisites on CM01, run from the HOST over PowerShell remoting as LAB\Administrator (no clicks inside CM01).
# Run on the HOST in a normal PowerShell, after 44 (CM01 joined to the domain). Long: ~20-40 min, mostly downloads.
# Same as, on CM01 by hand: Server Manager > Add Roles and Features (IIS bits, BITS, RDC, .NET 3.5), services.msc > Remote Registry
# > Automatic, then downloading and running: 7-Zip, VC++ 2015-2022 x64, ODBC Driver 18 for SQL Server 18.5.2.1, Windows ADK
# (Deployment Tools + USMT) + WinPE add-on, ConfigMgr 2509 eval (extracted), SQL Server 2022 eval media.
# Requirements and versions (Microsoft Learn, read 2026-11-05 via a research subagent, spot-checked):
#   "Site and site system prerequisites": site server .NET 3.5 + RDC; MP/DP: BITS, IIS ISAPI Extensions, Windows Authentication,
#     IIS 6 Metabase Compatibility, IIS 6 WMI Compatibility; DB server: Remote Registry; .NET 4.8+ (Server 2025 ships 4.8.1).
#   "List of prerequisite checks": ODBC min 18.4.1.1 for 2503-2603; DON'T install 18.6.1.1 (any) or 18.7.1.1 (2603 and older)
#     -> 18.5.2.1 (ODBC release notes, x64 link fwlink 2335671). ODBC 18.6 and older need the VC++ redistributable first.
#   "Support for the Windows ADK": 10.1.26100.x supported on 2509; current = 10.1.26100.9457 (fwlink 2289980 / WinPE 2289981).
#   Downloads: ConfigMgr_2509.exe (fwlink 2350307, 1.25 GB, eval page says extract with 7-Zip); SQL2022-SSEI-Eval.exe (fwlink 2215202).
$ErrorActionPreference = 'Stop'
$lab = Import-Clixml (Join-Path $env:USERPROFILE '.homelab\lab-admin.xml')

# .NET 3.5 source: first run 2026-11-05 failed with 0x80072f8f (secure-connection error) fetching it from Windows Update, although
# CM01's clock and HTTPS were fine. Microsoft's documented fallback is the ISO's \sources\sxs folder (Install-WindowsFeature -Source).
# Mount the Server ISO on the host (no admin needed), stage sxs on D:, clear read-only (Copy-Item -ToSession failed on the
# read-only ISO files with "The parameter is incorrect"), then copy it into CM01.
$sxs = 'D:\home-lab\sxs-server2025'
if (-not (Test-Path $sxs)) {
    $iso = Get-ChildItem 'D:\home-lab\iso\*SERVER_EVAL*.iso' | Select-Object -First 1
    $d = (Mount-DiskImage -ImagePath $iso.FullName -PassThru | Get-Volume).DriveLetter
    try { Copy-Item "${d}:\sources\sxs" $sxs -Recurse -Force } finally { Dismount-DiskImage -ImagePath $iso.FullName | Out-Null }
    Get-ChildItem $sxs -Recurse -File | ForEach-Object { $_.IsReadOnly = $false }
}
$s = New-PSSession -ComputerName 192.168.100.11 -Credential $lab
Invoke-Command -Session $s { New-Item -ItemType Directory -Force C:\Install\sxs | Out-Null }
Copy-Item -ToSession $s -Path "$sxs\*" -Destination 'C:\Install\sxs' -Recurse -Force
Remove-PSSession $s

Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
    $in = 'C:\Install'; New-Item -ItemType Directory -Force $in, "$in\logs" | Out-Null
    # Returns ONLY the path: anything else written to the output stream would become part of the return value (first run
    # 2026-11-05: the 'downloading' message rode along, msiexec got a garbled path and exited 1619). Messages go to Write-Host.
    function Get-File($url, $name) {
        $f = Join-Path $in $name   # $in is set inside this remote block, so no $using:
        if (-not (Test-Path $f)) { Write-Host "  downloading $name"; Invoke-WebRequest $url -OutFile $f -UseBasicParsing }
        $f
    }
    function Install-Quiet($file, $argList, $name) {
        $p = Start-Process $file -ArgumentList $argList -Wait -PassThru
        "  $name exit code: $($p.ExitCode)"
        if ($p.ExitCode -notin 0, 3010, 1638) { throw "$name failed ($($p.ExitCode))" }   # 1638 = newer version already installed
    }

    "1. Windows features"
    $features = 'NET-Framework-Core', 'BITS', 'BITS-IIS-Ext', 'RDC', 'Web-Server', 'Web-ISAPI-Ext', 'Web-Windows-Auth',
                'Web-Metabase', 'Web-WMI', 'Web-Mgmt-Console'
    Install-WindowsFeature -Name $features -Source C:\Install\sxs | Format-Table Success, RestartNeeded, ExitCode, FeatureResult -AutoSize | Out-String
    "2. Remote Registry"
    Set-Service RemoteRegistry -StartupType Automatic; Start-Service RemoteRegistry

    "3. Downloads (skipped if already there)"
    $z    = Get-File 'https://github.com/ip7z/7zip/releases/download/26.05/7z2605-x64.msi' '7z2605-x64.msi'
    $vc   = Get-File 'https://aka.ms/vs/17/release/vc_redist.x64.exe' 'vc_redist.x64.exe'
    # x86 too: ConfigMgr setup's OLE DB Driver 19 (msoledbsql.msi) checks for BOTH x64 and x86 VC++ 2022 and fails with 1603
    # without x86 (its MSI log: VCRedistX86Check, 2026-11-06)
    $vc86 = Get-File 'https://aka.ms/vs/17/release/vc_redist.x86.exe' 'vc_redist.x86.exe'
    $odbc = Get-File 'https://go.microsoft.com/fwlink/?linkid=2335671' 'msodbcsql-18.5.2.1-x64.msi'
    $adk  = Get-File 'https://go.microsoft.com/fwlink/?linkid=2289980' 'adksetup.exe'
    $pe   = Get-File 'https://go.microsoft.com/fwlink/?linkid=2289981' 'adkwinpesetup.exe'
    $cm   = Get-File 'https://go.microsoft.com/fwlink/?linkid=2350307' 'ConfigMgr_2509.exe'
    $sql  = Get-File 'https://go.microsoft.com/fwlink/?LinkID=2162123' 'SQL2022-SSEI-Eval.exe'   # NOT 2215202: the eval page's link serves a retired 16.2211 bootstrapper ("no longer supported", 2026-11-06)
    Get-AuthenticodeSignature "$in\*.exe", "$in\*.msi" | Format-Table @{n='File';e={Split-Path $_.Path -Leaf}}, Status, @{n='Signer';e={$_.SignerCertificate.Subject.Split(',')[0]}} -AutoSize | Out-String

    "4. Installs"
    Install-Quiet msiexec.exe "/i `"$z`" /qn /norestart /l*v `"$in\logs\7zip.log`"" '7-Zip'
    Install-Quiet $vc '/install /quiet /norestart' 'VC++ 2015-2022 x64'
    Install-Quiet $vc86 '/install /quiet /norestart' 'VC++ 2015-2022 x86'
    Install-Quiet msiexec.exe "/i `"$odbc`" /qn /norestart IACCEPTMSODBCSQLLICENSETERMS=YES /l*v `"$in\logs\odbc.log`"" 'ODBC Driver 18.5.2.1'
    Install-Quiet $adk '/quiet /norestart /features OptionId.DeploymentTools OptionId.UserStateMigrationTool' 'ADK (Deployment Tools + USMT)'
    Install-Quiet $pe  '/quiet /norestart /features OptionId.WindowsPreinstallationEnvironment' 'ADK WinPE add-on'

    "5. Extract ConfigMgr 2509 to C:\Install\CM"
    if (-not (Test-Path "$in\CM\SMSSETUP\BIN\X64\setup.exe")) {
        & 'C:\Program Files\7-Zip\7z.exe' x $cm "-o$in\CM" -y | Select-Object -Last 3
    }
    "  setup.exe present: $(Test-Path "$in\CM\SMSSETUP\BIN\X64\setup.exe")   extadsch.exe present: $(Test-Path "$in\CM\SMSSETUP\BIN\X64\extadsch.exe")"

    "6. Check"
    Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
        Where-Object DisplayName -match 'ODBC Driver 18|Visual C\+\+ 2015-20.. Redistributable \(x64\)|Windows Assessment and Deployment Kit|7-Zip' |
        Sort-Object DisplayName -Unique | Format-Table DisplayName, DisplayVersion -AutoSize | Out-String
    Get-WindowsFeature $features | Format-Table Name, InstallState -AutoSize | Out-String
}
