# 20 - give a synced user a password that works in Microsoft 365. Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Users from 10-create-users.ps1 have "must change password at next logon". The Cloud Sync FAQ says a user with that flag
# does NOT get their password hash sent to Entra until the password is changed, so the cloud sign-in fails.
# This clears the flag FIRST, then sets the password, so the change syncs as a real password (about 2 minutes).
# pwdLastSet 0 in the output = flag still on.
# Asks for the password; nothing secret is stored here.
param([string]$User = 'ppatel')

Set-ADUser -Identity $User -ChangePasswordAtLogon $false
Set-ADAccountPassword -Identity $User -Reset -NewPassword (Read-Host "New password for $User" -AsSecureString)
Get-ADUser $User -Properties PasswordLastSet, pwdLastSet | Select-Object SamAccountName, UserPrincipalName, PasswordLastSet, pwdLastSet
