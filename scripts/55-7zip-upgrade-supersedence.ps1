# 55 - Upgrade 7-Zip 26.05 (baked into ref.wim by script 28) to 26.06 with ConfigMgr: two Applications + supersedence + a Required deployment.
# Why two apps: ConfigMgr only knows about software it deployed. 26.05 came with the IMAGE, so a "7-Zip 26.05" Application exists
# only so 26.06 can SUPERSEDE it (and its MSI ProductCode detection can see the old version). It is never deployed.
# Why "Uninstall" stays UNTICKED on the supersedence: same product, newer version (Learn "Revise and supersede applications"), and the
# 26.06 MSI does its own major upgrade: its Upgrade table removes 7-Zip versions 4.38 through 26.06 (UpgradeCode
# {23170F69-40C1-2702-0000-000004000000}, RemoveExistingProducts in the sequence; read on the host 2026-11-07).
# Why Required: an upgrade is pushed, not offered; the client installs it at the deadline without anyone opening Software Center.
# ProductCodes (read from the MSIs by 52-stage-app): 26.05 {23170F69-40C1-2702-2605-000001000000}, 26.06 {23170F69-40C1-2702-2606-000001000000}.
# Done by hand in the CONSOLE. This file is the PowerShell record. UNTESTED as a script: the console clicks were the tested path.
# Learn: New-CMApplication, Add-CMMsiDeploymentType, Add-CMDeploymentTypeSupersedence, New-CMApplicationDeployment.
$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    Import-Module "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"; Set-Location LAB:
    $src = '\\CM01.lab.dupnet.internal\Sources\Apps\7-Zip'
    foreach ($v in '26.05', '26.06') {
        New-CMApplication -Name "7-Zip $v" -Publisher 'Igor Pavlov' -SoftwareVersion $v | Out-Null
        Add-CMMsiDeploymentType -ApplicationName "7-Zip $v" -DeploymentTypeName "7-Zip $v - MSI" `
            -ContentLocation "$src\$v\7z$($v -replace '\.')-x64.msi" -InstallationBehaviorType InstallForSystem -Force | Out-Null
        Start-CMContentDistribution -ApplicationName "7-Zip $v" -DistributionPointName 'CM01.lab.dupnet.internal'
    }
    $old = Get-CMDeploymentType -ApplicationName '7-Zip 26.05'
    $new = Get-CMDeploymentType -ApplicationName '7-Zip 26.06'
    Add-CMDeploymentTypeSupersedence -SupersededDeploymentType $old -SupersedingDeploymentType $new | Out-Null   # no -IsUninstall
    New-CMApplicationDeployment -Name '7-Zip 26.06' -CollectionName 'Workstations' -DeployAction Install -DeployPurpose Required `
        -DeadlineDateTime (Get-Date) -TimeBaseOn LocalTime -UserNotification DisplaySoftwareCenterOnly | Out-Null
}
