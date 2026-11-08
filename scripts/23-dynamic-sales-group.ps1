# 23 - "Sales Team": a Microsoft 365 group whose members come from AD's Department attribute. Run on the HOST in PowerShell.
# Same as entra.microsoft.com > Groups > New group: type Microsoft 365, membership Dynamic User, owner Morgan.
# Dynamic membership needs Entra ID P1 (Business Premium has it). Enabled users only, so offboarded Jordan
# (still Department = Sales, but disabled) stays out. Members can't be added by hand; owners can.
# 2026-10-29: creating it by hand also made admin@ an owner; removed afterwards so only Morgan owns it.
# First membership run can take up to 24 h (Microsoft); adding a space to the rule re-queues it.
# Needs the module once: Install-Module Microsoft.Graph -Scope CurrentUser
param(
    [string]$Rule  = '(user.department -eq "Sales") -and (user.accountEnabled -eq true)',
    [string]$Owner = 'mbrooks@contoso.onmicrosoft.com',   # change to your tenant
    [string]$Admin = 'admin@contoso.onmicrosoft.com'
)

Connect-MgGraph -Scopes 'Group.ReadWrite.All', 'User.Read.All'

$group = Get-MgGroup -Filter "displayName eq 'Sales Team'"
if (-not $group) {
    $group = New-MgGroup -DisplayName 'Sales Team' -Description 'Sales Team' -MailNickname 'SalesTeam' `
        -MailEnabled:$true -SecurityEnabled:$false -GroupTypes 'Unified', 'DynamicMembership' `
        -MembershipRule $Rule -MembershipRuleProcessingState 'On'
}

$ownerId = (Get-MgUser -UserId $Owner).Id
$owners  = (Get-MgGroupOwner -GroupId $group.Id).Id
if ($owners -notcontains $ownerId) {
    New-MgGroupOwnerByRef -GroupId $group.Id -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$ownerId" }
}
$adminId = (Get-MgUser -UserId $Admin).Id
if ($owners -contains $adminId) { Remove-MgGroupOwnerDirectoryObjectByRef -GroupId $group.Id -DirectoryObjectId $adminId }

Get-MgGroup -GroupId $group.Id -Property DisplayName, MembershipRule, MembershipRuleProcessingState |
    Select-Object DisplayName, MembershipRule, MembershipRuleProcessingState
Get-MgGroupOwner -GroupId $group.Id | ForEach-Object { $_.AdditionalProperties.userPrincipalName }
