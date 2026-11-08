# 12 - offboarding: a user has left. Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Same as ADUC: right-click > Disable Account; Properties > General > Description; Member Of > remove the groups;
# right-click > Move > Disabled. Disabled, not deleted: the account (and its SID, so file permissions and mailbox
# links still resolve) can come back if needed. Deleting is a later, separate decision.
param([string]$User = 'jlee')
$ErrorActionPreference = 'Stop'

$domain = (Get-ADDomain).DistinguishedName
$u = Get-ADUser $User -Properties MemberOf

Disable-ADAccount -Identity $User
Set-ADUser -Identity $User -Description "Left $(Get-Date -Format yyyy-MM-dd); disabled by $env:USERNAME"

# Take away access; Domain Users is the primary group and stays
foreach ($group in $u.MemberOf) {
    Remove-ADGroupMember -Identity $group -Members $User -Confirm:$false
    "removed from: $(($group -split ',')[0] -replace '^CN=')"
}

Move-ADObject -Identity $u.DistinguishedName -TargetPath "OU=Disabled,$domain"

Get-ADUser $User -Properties Description, MemberOf |
    Format-List SamAccountName, Enabled, Description, DistinguishedName, MemberOf
