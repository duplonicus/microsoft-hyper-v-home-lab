# 49 - Set ConfigMgr up to image PCs over the network: boundary group, Network Access Account, PXE on the distribution point,
# boot image, the ref.wim OS image, a task sequence, and its deployment to unknown computers.
# Run on the HOST in a normal PowerShell, after 48 (site installed; 48b update optional first). Over WinRM as LAB\Administrator:
# the ConfigMgr cmdlets talk to the SMS Provider on CM01 itself, so no double hop. Service-account passwords come from the host's
# DPAPI files and go straight into ConfigMgr (stored encrypted in the site); never printed.
# Same as, in the ConfigMgr console:
#   Administration > Boundaries > Create (IP range) + Boundary Groups > Create (site assignment LAB, site system CM01)
#   Administration > Sites > Configure Site Components > Software Distribution > Network Access Account = LAB\svc-cm-naa
#   Administration > Distribution Points > CM01 > PXE tab: Enable PXE, Enable a PXE responder without WDS, allow unknown computers
#   Software Library > Boot Images > Boot image (x64) > Data Source: Deploy this boot image from the PXE-enabled DP; Distribute
#   Software Library > Operating System Images > Add (\\CM01\Sources\OSD\Win11-Ref-v1\ref.wim); Distribute
#   Task Sequences > Create > Install an existing image package (partition, apply ref.wim, join domain with svc-cm-join into
#   OU=Workstations, install ConfigMgr client) > Deploy to "All Unknown Computers", Available, "Configuration Manager clients,
#   media and PXE" ... (Available = the PC asks for F12 at PXE: nobody re-images a lab by accident).
# Learn (read 2026-11-05/06): New-CMBoundary, New-CMBoundaryGroup, Add-CMBoundaryToGroup, Set-CMDistributionPoint (-EnablePxe,
# -EnableNonWdsPxe, -AllowPxeResponse, -EnableUnknownComputerSupport), New-CMOperatingSystemImage, Start-CMContentDistribution,
# New-CMTaskSequence (NewInstallOSImage set), New-CMTaskSequenceDeployment; "What's new in 2509": WinPE's boundary group must
# contain a management point (CM01 is both MP and DP here, so it goes in the group).
$ErrorActionPreference = 'Stop'
$sec  = Join-Path $env:USERPROFILE '.homelab'
$lab  = Import-Clixml "$sec\lab-admin.xml"
$naa  = Import-Clixml "$sec\svc-cm-naa.xml"
$join = Import-Clixml "$sec\svc-cm-join.xml"

Invoke-Command -ComputerName 192.168.100.11 -Credential $lab -ScriptBlock {
    $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
    $fqdn = "$env:COMPUTERNAME.$((Get-CimInstance Win32_ComputerSystem).Domain)"
    $site = 'LAB'

    "1. ref.wim onto a share ConfigMgr can read (\\$fqdn\Sources)"
    $img = Get-Disk | Where-Object { $_.Number -ne 0 -and $_.Size -lt 60GB } | Select-Object -First 1
    if ($img.IsOffline)  { Set-Disk -Number $img.Number -IsOffline $false }
    if ($img.IsReadOnly) { Set-Disk -Number $img.Number -IsReadOnly $false }
    $part = Get-Partition -DiskNumber $img.Number | Where-Object Type -eq 'Basic' | Select-Object -First 1
    if (-not $part.DriveLetter) { $part | Add-PartitionAccessPath -AssignDriveLetter; $part = $part | Get-Partition }
    $src = 'C:\Sources\OSD\Win11-Ref-v1'
    New-Item -ItemType Directory -Force $src | Out-Null
    if (-not (Test-Path "$src\ref.wim")) { Copy-Item "$($part.DriveLetter):\ref.wim" $src }
    if (-not (Get-SmbShare -Name Sources -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name Sources -Path C:\Sources -ReadAccess 'Everyone' -FullAccess 'BUILTIN\Administrators' | Out-Null }
    "  $src\ref.wim: $([math]::Round((Get-Item "$src\ref.wim").Length/1GB,2)) GB, shared as \\$fqdn\Sources"

    Import-Module (Join-Path (Split-Path $env:SMS_ADMIN_UI_PATH) 'ConfigurationManager.psd1')
    if (-not (Get-PSDrive -Name $site -ErrorAction SilentlyContinue)) { New-PSDrive -Name $site -PSProvider CMSite -Root $fqdn | Out-Null }
    Set-Location "${site}:"

    "2. Boundary + boundary group (with CM01 as site system: required for WinPE since 2509)"
    $bName = 'LabNAT 192.168.100.0/24'
    if (-not (Get-CMBoundary -BoundaryName $bName)) { New-CMBoundary -DisplayName $bName -BoundaryType IPRange -Value '192.168.100.1-192.168.100.254' | Out-Null }
    if (-not (Get-CMBoundaryGroup -Name 'LabNAT')) { New-CMBoundaryGroup -Name 'LabNAT' -DefaultSiteCode $site -AddSiteSystemServerName $fqdn | Out-Null }
    Add-CMBoundaryToGroup -BoundaryGroupName 'LabNAT' -BoundaryName $bName -ErrorAction SilentlyContinue

    "3. Network Access Account"
    if (-not (Get-CMAccount -UserName 'LAB\svc-cm-naa')) { New-CMAccount -UserName 'LAB\svc-cm-naa' -Password ($using:naa).Password -SiteCode $site | Out-Null }
    Set-CMSoftwareDistributionComponent -SiteCode $site -AddNetworkAccessAccountName 'LAB\svc-cm-naa'

    "4. PXE on the distribution point (responder without WDS, unknown computers allowed)"
    Set-CMDistributionPoint -SiteSystemServerName $fqdn -EnablePxe $true -EnableNonWdsPxe $true -AllowPxeResponse $true `
        -EnableUnknownComputerSupport $true -RespondToAllNetwork

    "5. Boot image: deploy from PXE DP, distribute"
    $boot = Get-CMBootImage | Where-Object { $_.Architecture -eq 9 } | Select-Object -First 1     # 9 = x64
    # No -EnableCommandSupport (F8 prompt): on 2509 it refused our ADK 10.1.26100 image as "legacy (WinPE 3.1 or earlier)" (2026-11-06).
    # Turn F8 on in the console instead if troubleshooting needs it (boot image > Properties > Customization).
    # Set-CMBootImage then refused -DeployFromPxeDistributionPoint the same way, while WMI shows ImageOSVersion 10.0.26100.1 and
    # ActionInProgress=1 (ConfigMgr still finishing the image). PkgFlags 0x400 = "deploy from PXE-enabled DP" (Claude's reading, NOT
    # checked on a Learn page); the default boot image already has it (PkgFlags=1024). Only call the cmdlet if the bit is off.
    $pkg = Get-CimInstance -Namespace "root\sms\site_$site" -ClassName SMS_BootImagePackage | Where-Object PackageID -eq $boot.PackageID
    if (($pkg.PkgFlags -band 0x400) -eq 0) {
        try { Set-CMBootImage -Id $boot.PackageID -DeployFromPxeDistributionPoint $true } catch { "  WARNING: Set-CMBootImage: $($_.Exception.Message)" }
    } else { "  boot image already set to deploy from the PXE DP (PkgFlags $($pkg.PkgFlags))" }
    try { Start-CMContentDistribution -BootImageId $boot.PackageID -DistributionPointName $fqdn } catch { "  (boot image: $($_.Exception.Message))" }

    "6. OS image from ref.wim, distribute"
    $os = Get-CMOperatingSystemImage -Name 'Win11-Ref-v1'
    if (-not $os) { $os = New-CMOperatingSystemImage -Name 'Win11-Ref-v1' -Path "\\$fqdn\Sources\OSD\Win11-Ref-v1\ref.wim" -Version '26H2 v1' }
    try { Start-CMContentDistribution -OperatingSystemImageId $os.PackageID -DistributionPointName $fqdn } catch { "  (OS image: $($_.Exception.Message))" }

    "7. ConfigMgr client package, distribute"
    $client = Get-CMPackage -Name 'Configuration Manager Client Package' -Fast
    try { Start-CMContentDistribution -PackageId $client.PackageID -DistributionPointName $fqdn } catch { "  (client package: $($_.Exception.Message))" }

    "8. Task sequence: install the existing image, join the domain as svc-cm-join, install the client"
    $ts = Get-CMTaskSequence -Name 'Deploy Win11-Ref-v1' -Fast
    if (-not $ts) {
        $ts = New-CMTaskSequence -InstallOperatingSystemImage -Name 'Deploy Win11-Ref-v1' `
            -BootImagePackageId $boot.PackageID -OperatingSystemImagePackageId $os.PackageID -OperatingSystemImageIndex 1 `
            -ClientPackagePackageId $client.PackageID -PartitionAndFormatTarget $true `
            -JoinDomain DomainType -DomainName 'lab.dupnet.internal' -DomainAccount 'LAB\svc-cm-join' -DomainPassword ($using:join).Password `
            -DomainOrganizationUnit 'LDAP://OU=Workstations,DC=lab,DC=dupnet,DC=internal' -GeneratePassword $true `
            -SoftwareUpdateStyle NoInstall
    }

    "9. Deploy to All Unknown Computers: Available, PXE + media (F12 at boot)"
    if (-not (Get-CMTaskSequenceDeployment -TaskSequenceId $ts.PackageID -Fast)) {
        New-CMTaskSequenceDeployment -TaskSequencePackageId $ts.PackageID -CollectionName 'All Unknown Computers' `
            -DeployPurpose Available -Availability MediaAndPxe | Out-Null
    }

    "10. Check"
    Get-CMDistributionStatus | Format-Table SoftwareName, Targeted, NumberSuccess, NumberInProgress, NumberErrors -AutoSize | Out-String
    Get-CMTaskSequence -Name 'Deploy Win11-Ref-v1' -Fast | Format-Table Name, PackageID -AutoSize | Out-String
    Set-Location C:
}
