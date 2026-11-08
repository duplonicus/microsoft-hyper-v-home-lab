# 16 - a GPO for the Staff OU, "Staff - Block Control Panel": no Control Panel or PC settings for Staff users.
# Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# Same as Group Policy Management > right-click Staff > "Create a GPO in this domain, and Link it here...",
# then Edit > User Configuration > Policies > Administrative Templates > Control Panel >
# "Prohibit access to Control Panel and PC settings" > Enabled.
# Safe to re-run: an existing GPO or link is left alone. (Made by hand as "Block Control Panel", renamed 2026-10-28;
# the PowerShell for that is Rename-GPO -Name 'Block Control Panel' -TargetName 'Staff - Block Control Panel'.)
$ErrorActionPreference = 'Stop'

$name  = 'Staff - Block Control Panel'
$staff = "OU=Staff,$((Get-ADDomain).DistinguishedName)"

if (-not (Get-GPO -Name $name -ErrorAction SilentlyContinue)) {
    New-GPO -Name $name -Comment 'Lab: Staff users get no Control Panel or PC settings.' | Out-Null
}

# The registry value that policy setting writes for each user it applies to
Set-GPRegistryValue -Name $name -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' `
    -ValueName NoControlPanel -Type DWord -Value 1 | Out-Null

if (-not ((Get-GPInheritance -Target $staff).GpoLinks | Where-Object DisplayName -eq $name)) {
    New-GPLink -Name $name -Target $staff | Out-Null
}

(Get-GPInheritance -Target $staff).GpoLinks | Format-Table DisplayName, Enabled, Enforced, Order
