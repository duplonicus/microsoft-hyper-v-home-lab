# 53 - Create the PuTTY 0.85 Application in ConfigMgr (MSI deployment type) and send its content to CM01's DP.
# Why: an Application = metadata + one or more DEPLOYMENT TYPES (how to install, how to DETECT it, requirements). For an MSI, the
# wizard fills the install command (msiexec /i ... /q) and the detection method (the MSI ProductCode) from the file itself.
# Content must then be distributed to a DP in the client's boundary group before any client can install it.
# Done by hand in the CONSOLE: Software Library > Application Management > Applications > Create Application > Windows Installer (MSI)
# > \\CM01.lab.dupnet.internal\Sources\Apps\PuTTY\0.85\putty-64bit-0.85-installer.msi > Next x3 > Close; then right-click the app >
# Distribute Content > Add > Distribution Point > CM01. This file is the PowerShell record. UNTESTED as a script: the console clicks were the tested path.
# Learn: New-CMApplication, Add-CMMsiDeploymentType, Start-CMContentDistribution.
$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    Import-Module "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"; Set-Location LAB:
    $app = New-CMApplication -Name 'PuTTY 0.85' -Publisher 'Simon Tatham' -SoftwareVersion '0.85'
    Add-CMMsiDeploymentType -ApplicationName $app.LocalizedDisplayName -DeploymentTypeName 'PuTTY 0.85 - MSI' `
        -ContentLocation '\\CM01.lab.dupnet.internal\Sources\Apps\PuTTY\0.85\putty-64bit-0.85-installer.msi' `
        -InstallationBehaviorType InstallForSystem -Force | Out-Null
    Start-CMContentDistribution -ApplicationName $app.LocalizedDisplayName -DistributionPointName 'CM01.lab.dupnet.internal'
    Get-CMDeploymentType -ApplicationName $app.LocalizedDisplayName | Format-Table LocalizedDisplayName, Technology -AutoSize | Out-String
}
