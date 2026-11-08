# 50b - Last 25 lines of SMSPXE.log on CM01, timestamps + message only (to follow a PXE boot live). Run on the HOST, not elevated.
# Same as: CM01 > CMTrace > C:\Program Files\Microsoft Configuration Manager\Logs\SMSPXE.log
$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
  Get-Content 'C:\Program Files\Microsoft Configuration Manager\Logs\SMSPXE.log' -Tail 25 | ForEach-Object { if ($_ -match 'LOG\[(.*?)\]LOG.*time="([\d:]+)') { "$($matches[2])  $($matches[1])" } }
}
