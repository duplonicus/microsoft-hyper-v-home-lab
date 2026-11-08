# 45a - Install the Windows ADK (Deployment Tools + USMT) and WinPE add-on on CM01 OFFLINE, from layouts downloaded on the host.
# Run on the HOST in a normal PowerShell, after 45 got as far as ODBC. ~10-20 min (copy ~GBs over WinRM, then install).
# Why: the ADK web installer on CM01 failed (exit 15605, log: HttpSendRequest failed) because plain HTTP (port 80) from the lab VMs to
# the internet times out (HTTPS works; NOW.md gotcha). Microsoft's documented way around no-internet installs: Learn "Install the
# ADK offline": `adksetup /quiet /layout <folder>` on a machine with internet, copy the folder, then run adksetup from it.
# Same as: on the host, adksetup.exe > "Download the Windows ADK for installation on a separate computer"; copy the folder to CM01;
# run adksetup.exe there and tick Deployment Tools + User State Migration Tool; same for the WinPE add-on.
$ErrorActionPreference = 'Stop'
$lab = Import-Clixml (Join-Path $env:USERPROFILE '.homelab\lab-admin.xml')
$layout = 'D:\home-lab\adk-layout'
if (-not (Test-Path "$layout\ADK\adksetup.exe") -or -not (Test-Path "$layout\WinPE\adkwinpesetup.exe")) {
    throw "Layouts missing in $layout. On the host: adksetup.exe /quiet /layout $layout\ADK  and  adkwinpesetup.exe /quiet /layout $layout\WinPE"
}

$s = New-PSSession -ComputerName 192.168.100.11 -Credential $lab
try {
    "Copying layouts to CM01:C:\Install\adk-layout ..."
    Invoke-Command -Session $s { New-Item -ItemType Directory -Force C:\Install\adk-layout | Out-Null }
    Copy-Item -ToSession $s -Path "$layout\ADK", "$layout\WinPE" -Destination 'C:\Install\adk-layout' -Recurse -Force
    Invoke-Command -Session $s -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $l = 'C:\Install\adk-layout'
        "  copied: $([math]::Round((Get-ChildItem $l -Recurse -File | Measure-Object Length -Sum).Sum/1GB,2)) GB"
        foreach ($x in @(
            @{ n = 'ADK (Deployment Tools + USMT)'; exe = "$l\ADK\adksetup.exe";        f = 'OptionId.DeploymentTools OptionId.UserStateMigrationTool' },
            @{ n = 'ADK WinPE add-on';              exe = "$l\WinPE\adkwinpesetup.exe"; f = 'OptionId.WindowsPreinstallationEnvironment' })) {
            $p = Start-Process $x.exe -ArgumentList "/quiet /norestart /features $($x.f)" -Wait -PassThru
            "  $($x.n) exit code: $($p.ExitCode)"
            if ($p.ExitCode -notin 0, 3010) { throw "$($x.n) failed ($($p.ExitCode)); log in %TEMP%\adk or %TEMP%\adkwinpeaddons" }
        }
        $k = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit'
        "  copype.cmd: $(Test-Path "$k\Windows Preinstallation Environment\copype.cmd")   winpe.wim: $(Test-Path "$k\Windows Preinstallation Environment\amd64\en-us\winpe.wim")   dism: $(Test-Path "$k\Deployment Tools\amd64\DISM\dism.exe")"

        "Extract ConfigMgr 2509 (the rest of script 45)"
        if (-not (Test-Path 'C:\Install\CM\SMSSETUP\BIN\X64\setup.exe')) {
            & 'C:\Program Files\7-Zip\7z.exe' x 'C:\Install\ConfigMgr_2509.exe' '-oC:\Install\CM' -y | Select-Object -Last 3
        }
        "  setup.exe: $(Test-Path 'C:\Install\CM\SMSSETUP\BIN\X64\setup.exe')   extadsch.exe: $(Test-Path 'C:\Install\CM\SMSSETUP\BIN\X64\extadsch.exe')"
    }
}
finally { Remove-PSSession $s }
