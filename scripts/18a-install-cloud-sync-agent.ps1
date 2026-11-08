# 18a - install and register the Microsoft Entra Cloud Sync (provisioning) agent on DC01, from the command line.
# Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell, after 18 is clean.
# Same as running ProvisioningAgentSetup.exe by hand: sign in to the tenant, let it create the gMSA
# (LAB\provAgentgMSA$), add the domain. Steps from Microsoft Learn, "Install the Microsoft Entra Connect cloud
# provisioning agent using a command-line interface (CLI) and PowerShell"; credentials are prompted for
# here instead of typed into the script.
# Get the installer first: entra.microsoft.com > Entra Connect > Cloud Sync > Agents >
# Download on-premises agent > Accept terms & download. Learn's two pages name it differently
# (AADConnectProvisioningAgentSetup.exe / ProvisioningAgentSetup.exe); this finds either in Downloads or C:\temp.
# Next: create the sync configuration in the Entra admin center (scope: the Staff and Disabled OUs).
$ErrorActionPreference = 'Stop'

$installer = Get-ChildItem "$env:USERPROFILE\Downloads", 'C:\temp' -Filter '*ProvisioningAgentSetup*.exe' -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $installer) { throw 'Download the agent first (see the header).' }

(Start-Process $installer.FullName -ArgumentList '/quiet' -NoNewWindow -PassThru).WaitForExit()

Import-Module 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Microsoft.CloudSync.PowerShell.dll'

# Sign in to the tenant as at least Hybrid Identity Administrator (admin@ is Global Admin).
# It only takes -Credential (no interactive window: a bare call fails with "Parameter set cannot be resolved",
# 2026-10-28). It worked with MFA on for admin@, right after an MFA sign-in with "remember" ticked; why isn't known.
Connect-AADCloudSyncAzureAD -Credential (Get-Credential -Message 'Entra admin, e.g. admin@contoso.onmicrosoft.com')

# Creates the gMSA the agent runs as; needs a domain admin. Learn says provAgentgMSA$, but on 2026-10-28 it was
# named pGMSA_<number>$ (the output of the next command shows it).
$domainAdmin = Get-Credential -Message 'Domain admin' -UserName 'LAB\Administrator'
Add-AADCloudSyncGMSA -Credential $domainAdmin
Add-AADCloudSyncADDomain -DomainName (Get-ADDomain).DNSRoot -Credential $domainAdmin

Restart-Service -Name AADConnectProvisioningAgent
Get-Service AADConnectProvisioningAgent | Format-Table Name, Status, StartType
