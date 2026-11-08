# 47 - Prepare Active Directory for ConfigMgr, from the HOST over remoting: extend the schema (extadsch.exe, run ON DC01, the schema
# master) and create the "System Management" container with Full Control for CM01's computer account.
# Run on the HOST in a normal PowerShell, after 45/45a (extadsch.exe comes out of the extracted ConfigMgr media on CM01).
# Same as: copying extadsch.exe to DC01 and double-clicking it as a Schema Admin, then ADSI Edit > CN=System > New Object >
# container "System Management" > Security > Add CM01$ > Full Control > Advanced > "This object and all descendant objects".
# Why: ConfigMgr publishes its site info (site code, management points, boundaries) there, so clients and WinPE can find the site.
# Steps from Learn "Extend the Active Directory schema for Configuration Manager" (read 2026-11-05). The schema extension is
# permanent and forest-wide (it only adds ConfigMgr's classes/attributes); it's the documented, normal step.
# extadsch runs on CM01 (from the media folder) as a scheduled task logged on as LAB\Administrator: see the note in the try block.
$ErrorActionPreference = 'Stop'
$lab = Import-Clixml (Join-Path $env:USERPROFILE '.homelab\lab-admin.xml')

$cm = New-PSSession -ComputerName 192.168.100.11 -Credential $lab
$dc = New-PSSession -ComputerName 192.168.100.10 -Credential $lab
try {
    # First run (2026-11-06): extadsch.exe copied alone to DC01 exited 0xC0000135 (STATUS_DLL_NOT_FOUND): it needs files from the
    # media folder / the VC++ runtime (installed on CM01 only). Learn only requires the account to be a Schema Admin, not that it runs
    # on the DC, so run it on CM01 from SMSSETUP\BIN\X64, as a scheduled task logged on as LAB\Administrator (no double hop).
    "1-2. Extend the schema (extadsch.exe on CM01, as LAB\Administrator)"
    Invoke-Command -Session $cm -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $bin = 'C:\Install\CM\SMSSETUP\BIN\X64'
        "Set-Location '$bin'; & .\extadsch.exe | Out-File C:\Install\logs\extadsch-console.txt; `$LASTEXITCODE | Set-Content C:\Install\logs\extadsch.exit" |
            Set-Content C:\Install\run-extadsch.ps1 -Encoding ascii
        Remove-Item C:\Install\logs\extadsch.exit -ErrorAction SilentlyContinue
        $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Install\run-extadsch.ps1'
        Register-ScheduledTask -TaskName 'Lab-ExtADSch' -Action $a -User 'LAB\Administrator' -Password ($using:lab).GetNetworkCredential().Password -RunLevel Highest -Force | Out-Null
        Start-ScheduledTask -TaskName 'Lab-ExtADSch'
        $t = (Get-Date).AddMinutes(5)
        while (-not (Test-Path C:\Install\logs\extadsch.exit) -and (Get-Date) -lt $t) { Start-Sleep 3 }
        Unregister-ScheduledTask -TaskName 'Lab-ExtADSch' -Confirm:$false
        "  extadsch exit code: $(Get-Content C:\Install\logs\extadsch.exit -ErrorAction SilentlyContinue)"
        Get-Content C:\ExtADSch.log -Tail 3 -ErrorAction SilentlyContinue
    }

    Invoke-Command -Session $dc -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        Import-Module ActiveDirectory
        "  ConfigMgr classes now in the schema: $((Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(cn=MS-SMS-*)' | Measure-Object).Count)"

        "3. System Management container + Full Control for CM01$"
        $sys = "CN=System,$((Get-ADDomain).DistinguishedName)"
        $dn  = "CN=System Management,$sys"
        if (-not (Get-ADObject -Filter "Name -eq 'System Management'" -SearchBase $sys -SearchScope OneLevel)) {
            New-ADObject -Name 'System Management' -Type container -Path $sys
            "  created $dn"
        } else { "  exists: $dn" }
        $sid  = (Get-ADComputer CM01).SID
        $acl  = Get-Acl "AD:$dn"
        # Explicit types: with plain strings PowerShell can't pick between the constructor's overloads ("Multiple ambiguous overloads", 2026-11-06)
        $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
            [System.Security.Principal.SecurityIdentifier]$sid,
            [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
            [System.Security.AccessControl.AccessControlType]::Allow,
            [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All)   # All = this object + all descendants
        $acl.AddAccessRule($rule); Set-Acl "AD:$dn" $acl
        (Get-Acl "AD:$dn").Access | Where-Object { $_.IdentityReference -match 'CM01' } |
            Format-Table IdentityReference, ActiveDirectoryRights, InheritanceType -AutoSize | Out-String
    }
}
finally { Remove-PSSession $cm, $dc }
