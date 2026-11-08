# 10 - Staff users and their groups, from a CSV. Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Same as ADUC > right-click Staff > New > User (and New > Group, then the group's Members tab).
# Safe to re-run: users and groups that already exist (like the two made by hand) aren't recreated;
# existing users still get their department, title and group. Asks once for the starting password; nothing secret is stored in the repo.
# Every new user must change that password at first sign-in.
# The list below is used when the script is pasted in; pass -Csv <path> to use a file with the same columns instead.
param([string]$Csv)
$ErrorActionPreference = 'Stop'

$list = @'
FirstName,LastName,SamAccountName,Department,Title,Group
Alex,Rivera,arivera,Sales,Account Manager,GG-Sales
Sam,Chen,schen,IT,Helpdesk Technician,GG-IT
Jordan,Lee,jlee,Sales,Sales Representative,GG-Sales
Priya,Patel,ppatel,IT,Systems Administrator,GG-IT
Morgan,Brooks,mbrooks,Sales,Sales Manager,GG-Sales
'@

$domain = Get-ADDomain
$staff  = "OU=Staff,$($domain.DistinguishedName)"
$users  = if ($Csv) { Import-Csv $Csv } else { $list | ConvertFrom-Csv }

$password = Read-Host 'Starting password for new users' -AsSecureString

# Global security groups by role (the G in AGDLP)
foreach ($group in $users.Group | Sort-Object -Unique) {
    if (Get-ADGroup -Filter "Name -eq '$group'") {
        "exists:  group $group"
    } else {
        New-ADGroup -Name $group -GroupScope Global -GroupCategory Security -Path $staff
        "created: group $group"
    }
}

foreach ($u in $users) {
    if (Get-ADUser -Filter "SamAccountName -eq '$($u.SamAccountName)'") {
        # Made by hand (the wizard has no Department/Title fields), so fill those in
        Set-ADUser -Identity $u.SamAccountName -Department $u.Department -Title $u.Title
        "exists:  user  $($u.SamAccountName) (department and title set)"
    } else {
        New-ADUser -Name "$($u.FirstName) $($u.LastName)" -GivenName $u.FirstName -Surname $u.LastName `
            -SamAccountName $u.SamAccountName -UserPrincipalName "$($u.SamAccountName)@$($domain.DNSRoot)" `
            -Department $u.Department -Title $u.Title -Path $staff `
            -AccountPassword $password -ChangePasswordAtLogon $true -Enabled $true
        "created: user  $($u.SamAccountName)"
    }
    if (-not (Get-ADGroupMember -Identity $u.Group | Where-Object SamAccountName -eq $u.SamAccountName)) {
        Add-ADGroupMember -Identity $u.Group -Members $u.SamAccountName
        "added:   $($u.SamAccountName) -> $($u.Group)"
    }
}

Get-ADUser -Filter * -SearchBase $staff -Properties Department, MemberOf |
    Format-Table SamAccountName, Name, Department, Enabled, @{n = 'Groups'; e = { ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }) -join ', ' } }
