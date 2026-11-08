# 22 - shared mailbox "Sales" with Full Access + Send As for two users. Run on the HOST in PowerShell, not on DC01:
# mailboxes live in Exchange Online (no on-prem Exchange), so this is cloud-side, signed in as admin@.
# Same as admin.microsoft.com > Teams & groups > Shared mailboxes > Add, then Members ("Read and manage" + "Send as").
# Needs the module once: Install-Module ExchangeOnlineManagement -Scope CurrentUser
# A shared mailbox needs no licence and has no password; people open it with their own sign-in.
# Permissions can take a while to show in the admin center (2026-10-29: Alex looked missing, Delegation in EAC showed him).
param(
    [string]$Name = 'Sales',
    [string]$Alias = 'sales',
    [string[]]$Members = @('ppatel@contoso.onmicrosoft.com', 'arivera@contoso.onmicrosoft.com')   # change to your tenant
)

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline

if (-not (Get-Mailbox -Identity $Alias -ErrorAction SilentlyContinue)) {
    New-Mailbox -Shared -Name $Name -DisplayName $Name -Alias $Alias | Out-Null
}
foreach ($m in $Members) {
    Add-MailboxPermission -Identity $Alias -User $m -AccessRights FullAccess -InheritanceType All -AutoMapping $true | Out-Null
    Add-RecipientPermission -Identity $Alias -Trustee $m -AccessRights SendAs -Confirm:$false | Out-Null
}

Get-MailboxPermission -Identity $Alias | Where-Object { $_.User -like '*@*' } | Select-Object User, AccessRights
Get-RecipientPermission -Identity $Alias | Where-Object { $_.Trustee -like '*@*' } | Select-Object Trustee, AccessRights
