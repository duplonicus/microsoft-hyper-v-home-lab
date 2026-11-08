# 50g - Make the PXE build ASK for a computer name, and make PC02 "unknown" again so it can be rebuilt.
# Why: run 3 named PC02 "MININT-I0KM8TI" (WinPE's random name), because nothing set OSDComputerName for unknown computers.
# A collection variable OSDComputerName with NO value on All Unknown Computers (SMS000US) makes the Task Sequence Wizard show a
# "Edit Task Sequence Variables" page where you type the name (archived Learn/TechNet wiki 931 + community posts; works only with an
# Available deployment, which ours is). Leaving it blank and clicking Next falls back to a MININT name.
# PC02's MAC now belongs to a ConfigMgr device record, so PXE treats it as KNOWN and won't offer a deployment aimed at All Unknown
# Computers: that record has to go first (the "Clear Required PXE Deployments" trick doesn't help here; the deployment isn't Required).
# Done by hand in the CONSOLE: Assets and Compliance > Device Collections > All Unknown Computers > Properties > Collection Variables
# > New (star) > Name OSDComputerName, Value empty, untick "Do not display this value" > OK > OK; then Devices > the record with MAC
# 00:15:5D:28:02:04 > Delete. This file is the PowerShell record. UNTESTED as a script: the console clicks were the tested path.
$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    Import-Module "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"; Set-Location LAB:
    New-CMDeviceCollectionVariable -CollectionId SMS000US -VariableName OSDComputerName -Value '' -IsMask $false
    Get-CMDevice | Where-Object MACAddress -eq '00:15:5D:28:02:04' | Remove-CMDevice -Force
    Get-CMDeviceCollectionVariable -CollectionId SMS000US | Format-Table Name, Value, IsMasked -AutoSize | Out-String
}
