# 27 - Windows ADK (Deployment Tools only) + the Windows PE add-on, on the HOST.
# Run on the HOST in an Administrator PowerShell (<path to this repo>\scripts\\, -ExecutionPolicy Bypass).
# Same as downloading adksetup.exe + adkwinpesetup.exe from Microsoft Learn ("Download and install the Windows ADK")
# and ticking only "Deployment Tools", then running the WinPE add-on installer.
# Why: step 6 (network imaging) needs a custom WinPE boot image, and copype / MakeWinPEMedia / the WinPE files come from these two.
# Version: ADK 10.1.26100.9457 (September 2026), supports Windows 11 26H2 (Learn, checked 2026-11-05).
# Silent-install syntax for adksetup is from Learn "Install the ADK offline"; the WinPE feature id is NOT checked on Learn.
# Install path is FORCED to C:\Program Files (x86)\Windows Kits\10 on this host: the Windows SDK (from Visual Studio) already owns
# that "Windows Kits" folder, and the ADK installer refuses any other path. First run 2026-11-05 with /installpath D:\home-lab\adk:
# exit code 1001 (0x3e9), log line "Cannot set the path to D:\home-lab\adk because another installation has already been detected".
# Only the kit (a few GB) goes on C:; WinPE working folders and images stay on D:. Logs: %TEMP%\adk and %TEMP%\adkwinpeaddons.
# Safe to re-run: downloads are skipped if present, the installers skip what is already installed.
$ErrorActionPreference = 'Stop'

$setup = 'D:\home-lab\adk-setup'
$path  = 'C:\Program Files (x86)\Windows Kits\10'   # forced by the existing Windows SDK, see header
New-Item -ItemType Directory -Force $setup | Out-Null

# The two small online installers (they download the real payload while installing)
if (-not (Test-Path "$setup\adksetup.exe"))      { Invoke-WebRequest 'https://go.microsoft.com/fwlink/?linkid=2289980' -OutFile "$setup\adksetup.exe" }
if (-not (Test-Path "$setup\adkwinpesetup.exe")) { Invoke-WebRequest 'https://go.microsoft.com/fwlink/?linkid=2289981' -OutFile "$setup\adkwinpesetup.exe" }
Get-AuthenticodeSignature "$setup\*.exe" | Format-Table Path, Status, @{n='Signer';e={$_.SignerCertificate.Subject.Split(',')[0]}}

# Deployment Tools: DISM, BCDBoot, oscdimg, the "Deployment and Imaging Tools Environment" prompt
$p = Start-Process "$setup\adksetup.exe" -Wait -PassThru `
    -ArgumentList '/quiet', '/norestart', '/features', 'OptionId.DeploymentTools'
"adksetup exit code: $($p.ExitCode)  (0 = OK)"

# Windows PE add-on: the WinPE boot files + copype
$p = Start-Process "$setup\adkwinpesetup.exe" -Wait -PassThru `
    -ArgumentList '/quiet', '/norestart', '/features', 'OptionId.WindowsPreinstallationEnvironment'
"adkwinpesetup exit code: $($p.ExitCode)  (0 = OK)"

# Check: copype and the amd64 WinPE boot image should now exist
Get-ChildItem "$path\Assessment and Deployment Kit\Windows Preinstallation Environment\copype.cmd",
              "$path\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim" -ErrorAction Continue |
    Format-Table FullName, @{n='MB';e={[math]::Round($_.Length/1MB)}}
