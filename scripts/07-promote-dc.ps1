# 07 - promote DC01 to the first domain controller of a new forest, lab.dupnet.internal.
# Run INSIDE DC01 in an Administrator PowerShell, after 06-install-adds.ps1. Take a Hyper-V checkpoint first.
# This is the script the Server Manager promotion wizard exported (Review Options > View script), 2026-10-28.
# It prompts for the DSRM (Directory Services Restore Mode) password; keep that in a password manager, not here.
# Installs DNS, points DC01's DNS at itself, and reboots. Sign in afterwards as LAB\Administrator.

Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\WINDOWS\NTDS" `
-DomainMode "Win2025" `
-DomainName "lab.dupnet.internal" `
-DomainNetbiosName "LAB" `
-ForestMode "Win2025" `
-InstallDns:$true `
-LogPath "C:\WINDOWS\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\WINDOWS\SYSVOL" `
-Force:$true
