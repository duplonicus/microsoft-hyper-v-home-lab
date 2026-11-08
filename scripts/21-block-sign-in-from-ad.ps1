# 21 - block a synced user's Microsoft 365 sign-in from AD. Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Same as ADUC > right-click the user > Disable Account (and Enable Account to undo). For synced users AD is the source:
# Cloud Sync carries the disabled state to Entra, which blocks sign-in after the next sync cycle (minutes, not instant).
param([string]$User = 'ppatel', [switch]$Enable)

if ($Enable) { Enable-ADAccount -Identity $User } else { Disable-ADAccount -Identity $User }
Get-ADUser $User | Select-Object SamAccountName, Enabled
