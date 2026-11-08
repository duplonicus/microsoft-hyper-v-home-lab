# 17 - Microsoft 365 cloud users with a Business Premium licence, through Microsoft Graph PowerShell.
# Run INSIDE DC01 (or any PC) in an Administrator PowerShell; signs in to the tenant in a browser window.
# Same as admin.microsoft.com > Users > Active users > Add a user (name, username, licence, "require password change").
# Microsoft Graph PowerShell replaced the retired MSOnline / AzureAD modules (New-MsolUser > New-MgUser).
# Safe to re-run: existing users are left alone but still get a licence. Asks for the starting password once.
param([Parameter(Mandatory)][string]$TenantDomain)   # your tenant, e.g. contoso.onmicrosoft.com
$ErrorActionPreference = 'Stop'

$tenant = $TenantDomain
$list = @'
FirstName,LastName,Alias,Department
Casey,Nguyen,cnguyen,Sales
Riley,Ortiz,rortiz,IT
Avery,Shah,ashah,Sales
'@ | ConvertFrom-Csv

foreach ($module in 'Microsoft.Graph.Users', 'Microsoft.Graph.Identity.DirectoryManagement') {
    if (-not (Get-Module -ListAvailable $module)) { Install-Module $module -Scope CurrentUser -Force }
}
Connect-MgGraph -Scopes 'User.ReadWrite.All', 'Organization.Read.All' -NoWelcome

# Business Premium's product code is SPB
$sku = Get-MgSubscribedSku | Where-Object SkuPartNumber -eq 'SPB'
if (-not $sku) { throw "No Business Premium (SPB) licences. This tenant has: $((Get-MgSubscribedSku).SkuPartNumber -join ', ')" }

$secure = Read-Host 'Starting password for new users' -AsSecureString
$plain  = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

foreach ($u in $list) {
    $upn = "$($u.Alias)@$tenant"
    if (Get-MgUser -Filter "userPrincipalName eq '$upn'") {
        "exists:  $upn"
    } else {
        New-MgUser -DisplayName "$($u.FirstName) $($u.LastName)" -GivenName $u.FirstName -Surname $u.LastName `
            -UserPrincipalName $upn -MailNickname $u.Alias -Department $u.Department `
            -UsageLocation 'CA' -AccountEnabled `
            -PasswordProfile @{ Password = $plain; ForceChangePasswordNextSignIn = $true } | Out-Null
        "created: $upn"
    }
    # A licence needs a usage location (the country the user works in) set first
    Update-MgUser -UserId $upn -UsageLocation 'CA'
    Set-MgUserLicense -UserId $upn -AddLicenses @(@{ SkuId = $sku.SkuId }) -RemoveLicenses @() | Out-Null
}
$plain = $null

Get-MgUser -All -Property DisplayName, UserPrincipalName, Department, AssignedLicenses |
    Format-Table DisplayName, UserPrincipalName, Department, @{ n = 'Licences'; e = { $_.AssignedLicenses.Count } }
