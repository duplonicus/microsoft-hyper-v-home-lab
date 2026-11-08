# 50f - After the PXE build: did the new PC land in AD and in ConfigMgr? Run on the HOST, not elevated.
# AD (DC01): computer accounts created today, with their OU. ConfigMgr (CM01): the device record, client installed/active,
# and the task sequence deployment's summary (after summarization).
# Same as: ADUC > lab.dupnet.internal > Workstations; CM console > Assets and Compliance > Devices; Monitoring > Deployments.
$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
'=== AD: computers created in the last day ==='
Invoke-Command -ComputerName 192.168.100.10 -Credential $lab -ScriptBlock {
    Get-ADComputer -Filter * -Properties whenCreated, OperatingSystem, OperatingSystemVersion |
        Where-Object whenCreated -gt (Get-Date).AddDays(-1) |
        Format-Table Name, DistinguishedName, OperatingSystem, OperatingSystemVersion, whenCreated -AutoSize | Out-String -Width 250
}
'=== ConfigMgr ==='
Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    Import-Module "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"; Set-Location LAB:
    Get-CMDevice | Where-Object { $_.Name -notin 'CM01','DC01' } |
        Format-Table Name, IsClient, IsActive, ClientVersion, MACAddress, LastActiveTime -AutoSize | Out-String -Width 250
    Invoke-CMDeploymentSummarization -CollectionId SMS000US -ErrorAction SilentlyContinue
    Get-CMDeployment -SoftwareName 'Deploy Win11-Ref-v1' |
        Format-Table SoftwareName, NumberSuccess, NumberInProgress, NumberErrors, NumberUnknown, SummarizationTime -AutoSize | Out-String -Width 250
}
