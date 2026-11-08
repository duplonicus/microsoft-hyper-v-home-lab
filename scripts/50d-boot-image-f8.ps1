# 50d - Turn on F8 command support in the x64 boot image, so WinPE can open a command prompt (and CMTrace) during a deployment.
# Why: PC02 rebooted ~11 s after the TS was picked in the wizard, with a RAW disk and no TS status messages, so smsts.log lived only
# on X: (RAM) and was lost. With F8 on, an open command prompt also STOPS WinPE from rebooting, so the log can be read in place.
# Testing only: anyone at the PXE screen gets a SYSTEM command prompt. Turn it back off when done.
# Done by hand in the CONSOLE (the tested path): Software Library > Operating Systems > Boot Images > Boot image (x64) > Properties >
# Customization > "Enable command support (testing only)" > OK > Yes (update distribution points) > wizard Next/Close.
# This file is the PowerShell record of that click path, UNTESTED as a script. EnableLabShell is the documented WMI property behind the
# checkbox (Learn: SMS_BootImagePackage); calling RefreshPkgSource afterwards to rebuild/redistribute is my inference, not stated there.
$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    $p = Get-CimInstance -Namespace root\sms\site_LAB -ClassName SMS_BootImagePackage | Where-Object PackageID -eq 'LAB00002'
    $p = $p | Get-CimInstance      # lazy properties
    "before: EnableLabShell = $($p.EnableLabShell)"
    Set-CimInstance -InputObject $p -Property @{ EnableLabShell = $true }
    Invoke-CimMethod -InputObject $p -MethodName RefreshPkgSource | Out-Null
    "after: EnableLabShell = $((Get-CimInstance -Namespace root\sms\site_LAB -ClassName SMS_BootImagePackage -Filter "PackageID='LAB00002'" | Get-CimInstance).EnableLabShell)"
}
