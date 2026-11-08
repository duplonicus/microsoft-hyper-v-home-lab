# 48a - Two least-privilege service accounts for ConfigMgr OS deployment, created on DC01 from the HOST over remoting.
#   svc-cm-naa   Network Access Account: WinPE has no domain identity, so the task sequence uses this plain domain user to read
#                content from the distribution point (Learn "Accounts used in Configuration Manager": the NAA is what a PXE-booted
#                task sequence uses unless the site runs Enhanced HTTP/HTTPS).
#   svc-cm-join  Domain join account for the task sequence, delegated ONLY "create/delete computer objects" + full control over
#                computer objects inside OU=Workstations. So the task sequence never holds a domain admin password.
# Run on the HOST in a normal PowerShell. Passwords: 24 random chars generated here, created on DC01, stored on the host as
# DPAPI files (%USERPROFILE%\.homelab\svc-cm-naa.xml, svc-cm-join.xml). Never printed.
# Same as: ADUC > Users > New > User (x2, password never expires); then right-click OU Workstations > Delegate Control >
# svc-cm-join > custom task > Computer objects > Create + Delete selected objects in this folder, Full Control.
# Safe to re-run: existing accounts get a new password (and the DPAPI file is rewritten to match).
$ErrorActionPreference = 'Stop'
$sec = Join-Path $env:USERPROFILE '.homelab'
$lab = Import-Clixml "$sec\lab-admin.xml"
$chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'

foreach ($name in 'svc-cm-naa', 'svc-cm-join') {
    $pw   = (-join (1..20 | ForEach-Object { $chars | Get-Random })) + 'x9K#'
    $cred = New-Object PSCredential("LAB\$name", (ConvertTo-SecureString $pw -AsPlainText -Force))
    Invoke-Command -ComputerName 192.168.100.10 -Credential $lab -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $n = $using:name; $c = $using:cred
        $usersPath = "CN=Users,$((Get-ADDomain).DistinguishedName)"
        if (Get-ADUser -Filter "SamAccountName -eq '$n'") {
            Set-ADAccountPassword $n -Reset -NewPassword $c.Password; "  $n exists: password reset"
        } else {
            New-ADUser -Name $n -SamAccountName $n -UserPrincipalName "$n@lab.dupnet.internal" -Path $usersPath `
                -AccountPassword $c.Password -Enabled $true -PasswordNeverExpires $true -CannotChangePassword $true `
                -Description 'ConfigMgr OSD service account (home lab)'
            "  $n created"
        }
    }
    $cred | Export-Clixml "$sec\$name.xml"
}

"Delegating computer-object rights on OU=Workstations to svc-cm-join"
Invoke-Command -ComputerName 192.168.100.10 -Credential $lab -ScriptBlock {
    $ou = "OU=Workstations,$((Get-ADDomain).DistinguishedName)"
    # CCDC;computer on the OU = create/delete computer objects; GA;;computer inherited onto computer objects = full control of them
    dsacls $ou /I:T /G 'LAB\svc-cm-join:CCDC;computer' | Select-Object -Last 1
    dsacls $ou /I:S /G 'LAB\svc-cm-join:GA;;computer'  | Select-Object -Last 1
    Get-ADUser -Filter "SamAccountName -like 'svc-cm-*'" | Format-Table SamAccountName, Enabled, DistinguishedName -AutoSize | Out-String
}
