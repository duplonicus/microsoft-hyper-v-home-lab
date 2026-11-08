# 14 - lock a test account on purpose, to practise unlocking it. Run INSIDE DC01 as LAB\Administrator.
# Signs in to AD as the user with wrong passwords until the lockout policy (13: 5 attempts) locks it,
# which is what a user hammering an old password into their PC does. There's no client VM, so this
# stands in for "user typed the wrong password 5 times".
# Next: unlock it by hand (ADUC > user > Properties > Account > Unlock account) or with 15-unlock-user.ps1.
param([string]$User = 'mbrooks')
$ErrorActionPreference = 'Stop'

$threshold = (Get-ADDefaultDomainPasswordPolicy).LockoutThreshold
if ($threshold -eq 0) { throw 'Lockout is off (threshold 0); run 13-lockout-policy.ps1 / edit the Default Domain Policy first.' }

foreach ($i in 1..($threshold + 1)) {
    $entry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$env:COMPUTERNAME", "LAB\$User", "wrong-password-$i")
    try { $null = $entry.NativeObject; "attempt ${i}: signed in?!" }
    catch { "attempt ${i}: $($_.Exception.Message.Trim())" }
}

Get-ADUser $User -Properties LockedOut, BadLogonCount, LockoutTime | Format-List SamAccountName, LockedOut, BadLogonCount, LockoutTime
Search-ADAccount -LockedOut | Format-Table SamAccountName, LockedOut
