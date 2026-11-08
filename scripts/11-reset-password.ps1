# 11 - helpdesk ticket: "I forgot my password". Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Same as ADUC > right-click the user > Reset Password, with "User must change password at next logon" ticked
# (and "Unlock the user's account" if it is locked). Asks for the temporary password; nothing secret is stored here.
param([string]$User = 'arivera')
$ErrorActionPreference = 'Stop'

Set-ADAccountPassword -Identity $User -Reset -NewPassword (Read-Host "Temporary password for $User" -AsSecureString)
Set-ADUser -Identity $User -ChangePasswordAtLogon $true
Unlock-ADAccount -Identity $User   # harmless if it wasn't locked

# pwdLastSet = 0 is how AD stores "must change at next logon"
Get-ADUser $User -Properties pwdLastSet, LockedOut | Format-Table SamAccountName, Enabled, LockedOut, pwdLastSet
