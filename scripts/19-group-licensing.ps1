# 19 - group-based licensing: everyone in GG-Sales or GG-IT gets Microsoft 365 Business Premium automatically.
# Run INSIDE DC01 (or any PC) in an Administrator PowerShell; signs in to the tenant in a browser window.
# Same as admin.microsoft.com > Billing > Licenses > Assign licenses > pick the group > the subscription > Assign licenses.
# The groups are synced from AD (Cloud Sync), so a new hire added to GG-Sales in ADUC is licensed with no cloud clicks.
# Users with no usage location get the tenant's (Learn, "Assign or unassign licenses to a group").
# Safe to re-run: assigning a licence a group already has changes nothing.
$ErrorActionPreference = 'Stop'

foreach ($module in 'Microsoft.Graph.Groups', 'Microsoft.Graph.Identity.DirectoryManagement') {
    if (-not (Get-Module -ListAvailable $module)) { Install-Module $module -Scope CurrentUser -Force }
}
Connect-MgGraph -Scopes 'Group.ReadWrite.All', 'Organization.Read.All', 'Directory.ReadWrite.All' -NoWelcome

# Business Premium's product code is SPB (stops with the real list if not)
$sku = Get-MgSubscribedSku | Where-Object SkuPartNumber -eq 'SPB'
if (-not $sku) { throw "No Business Premium (SPB) licences. This tenant has: $((Get-MgSubscribedSku).SkuPartNumber -join ', ')" }

foreach ($name in 'GG-Sales', 'GG-IT') {
    $group = Get-MgGroup -Filter "displayName eq '$name'"
    if (-not $group) { throw "$name isn't in Entra yet; check Cloud Sync." }
    Set-MgGroupLicense -GroupId $group.Id -AddLicenses @(@{ SkuId = $sku.SkuId }) -RemoveLicenses @() | Out-Null
    "licensed: $name"
}

"Business Premium: $($sku.ConsumedUnits) of $($sku.PrepaidUnits.Enabled) in use (refreshes after processing)"
