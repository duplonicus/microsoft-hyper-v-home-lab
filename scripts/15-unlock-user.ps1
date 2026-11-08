# 15 - helpdesk ticket: "I'm locked out". Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Same as ADUC > the user > Properties > Account tab > tick "Unlock account".
# Unlocking doesn't change the password; if they forgot it, that's 11-reset-password.ps1.
param([string]$User = 'mbrooks')
$ErrorActionPreference = 'Stop'

Search-ADAccount -LockedOut | Format-Table SamAccountName, LockedOut   # who is locked right now
Unlock-ADAccount -Identity $User
Get-ADUser $User -Properties LockedOut | Format-Table SamAccountName, LockedOut
