# 09 - the lab's OUs, at the top of the domain. Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Same as Active Directory Users and Computers > right-click the domain > New > Organizational Unit.
# Safe to re-run: an OU that already exists is reported and left alone.
# "Workstations", not "Computers": the domain already has a built-in Computers container.
$ErrorActionPreference = 'Stop'

$domain = (Get-ADDomain).DistinguishedName

foreach ($name in 'Staff', 'Workstations', 'Disabled') {
    if (Get-ADOrganizationalUnit -Filter "Name -eq '$name'" -SearchBase $domain -SearchScope OneLevel) {
        "exists:  $name"
    } else {
        New-ADOrganizationalUnit -Name $name -Path $domain -ProtectedFromAccidentalDeletion $true
        "created: $name"
    }
}

Get-ADOrganizationalUnit -Filter * | Format-Table Name, DistinguishedName, ProtectedFromAccidentalDeletion
