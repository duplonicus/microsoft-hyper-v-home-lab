# 06 - install the Active Directory Domain Services role on DC01. Run INSIDE DC01 in an Administrator PowerShell.
# Same as Server Manager > Add Roles and Features > Active Directory Domain Services.
# Only installs the role; DNS comes with the promotion. Take a Hyper-V checkpoint first.
# Next: promote DC01 to a domain controller.
$ErrorActionPreference = 'Stop'

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Get-WindowsFeature AD-Domain-Services | Format-Table Name, InstallState
