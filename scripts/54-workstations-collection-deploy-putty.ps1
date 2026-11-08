# 54 - A "Workstations" device collection built from the AD OU, and PuTTY 0.85 deployed to it as Available.
# Why a QUERY rule on the OU (not a direct rule naming PC02): every machine the PXE build joins to OU=Workstations lands in the
# collection by itself, so the app follows the OU. PC02's SystemOUName (from its discovery data) is LAB.DUPNET.INTERNAL/WORKSTATIONS.
# Incremental updates = new members show up within minutes instead of waiting for the scheduled full update.
# Available = shows in Software Center for the user to install; Required would install on its own at the deadline.
# Done by hand in the CONSOLE (Create Device Collection wizard with a Query Rule; then right-click PuTTY 0.85 > Deploy).
# This file is the PowerShell record. UNTESTED as a script: the console clicks were the tested path. Learn: New-CMDeviceCollection, Add-CMDeviceCollectionQueryMembershipRule,
# New-CMApplicationDeployment.
$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    Import-Module "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"; Set-Location LAB:
    $c = New-CMDeviceCollection -Name 'Workstations' -LimitingCollectionName 'All Desktop and Server Clients' -RefreshType Both
    Add-CMDeviceCollectionQueryMembershipRule -CollectionId $c.CollectionID -RuleName 'OU Workstations' -QueryExpression `
        "select * from SMS_R_System where SMS_R_System.SystemOUName = 'LAB.DUPNET.INTERNAL/WORKSTATIONS'"
    New-CMApplicationDeployment -Name 'PuTTY 0.85' -CollectionId $c.CollectionID -DeployAction Install -DeployPurpose Available `
        -UserNotification DisplaySoftwareCenterOnly | Out-Null
    Get-CMDeviceCollection -Id $c.CollectionID | Format-Table Name, CollectionID, MemberCount -AutoSize | Out-String
}
