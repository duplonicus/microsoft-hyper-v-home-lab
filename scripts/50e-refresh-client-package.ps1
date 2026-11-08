# 50e - Fix for PC02's 0x80040104: the TS deployment (LAB20001) had dependency policies for the boot image (LAB00002) and OS image
# (LAB00006) but NONE for the client package (LAB00004), so WinPE's TS resolver failed with "a package referenced by the task sequence
# could not be found" (smsts.log: Failed to find CCM_SoftwareDistribution object for AdvertID="LAB20001", PackageID="LAB00004").
# The content itself was on CM01's DP (State 0). Updating the package's DPs bumps its version, which makes the policy provider rebuild
# the deployment's package policies. Then the check: a DEP-LAB20001-LAB00004-* row in the site database's Policy table.
# Done by hand in the CONSOLE: Software Library > Application Management > Packages > "Configuration Manager Client Package" >
# right-click > Update Distribution Points > Yes. This file is the PowerShell record (RefreshPkgSource = Learn's "refresh the package
# source at all distribution points", the same thing the console button does) plus the check.
$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    param([bool]$CheckOnly)
    if (-not $CheckOnly) {
        $p = Get-CimInstance -Namespace root\sms\site_LAB -ClassName SMS_Package -Filter "PackageID='LAB00004'"
        Invoke-CimMethod -InputObject $p -MethodName RefreshPkgSource | Out-Null
        'LAB00004 refresh requested.'
    }
    Invoke-Sqlcmd -ServerInstance localhost -Database CM_LAB -Query "SELECT PolicyID, Version FROM Policy WHERE PolicyID LIKE 'DEP-LAB20001-%' ORDER BY PolicyID" | Format-Table -AutoSize | Out-String
} -ArgumentList ($args -contains '-CheckOnly')
