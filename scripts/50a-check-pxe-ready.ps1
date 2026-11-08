# 50a - Before PC02's first boot: is ConfigMgr ready to answer its PXE request?
# Checks on CM01 (over WinRM as LAB\Administrator): the PXE responder service, the task sequence deployment to
# All Unknown Computers, and the last lines of SMSPXE.log. Run on the HOST, not elevated.
# Same as: CM01 services.msc > "ConfigMgr PXE Responder Service"; console > Monitoring > Deployments; CMTrace on SMSPXE.log.
$ErrorActionPreference = 'Stop'
$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    Get-Service SccmPxe | Format-Table Name, Status, StartType -AutoSize | Out-String
    Import-Module "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"
    Set-Location LAB:
    Get-CMDeployment -SoftwareName 'Deploy Win11-Ref-v1' |
        Format-Table SoftwareName, CollectionName, DeploymentIntent, NumberTargeted -AutoSize | Out-String
    $log = Get-ChildItem 'C:\Program Files\Microsoft Configuration Manager\Logs\SMSPXE.log', 'C:\Program Files\SMS_CCM\Logs\SMSPXE.log' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($log) { "--- $($log.FullName) (last 5) ---"; Get-Content $log.FullName -Tail 5 } else { 'SMSPXE.log not found' }
}
