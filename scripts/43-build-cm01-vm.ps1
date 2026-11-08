# 43 - Build CM01 (the Configuration Manager server) without clicking through Windows Setup: apply Server 2025 straight from the
# ISO's install.wim onto a new VHDX with DISM (the same apply-an-image idea as step 5), drop in an unattend.xml so first boot
# needs no answers, and create + start the VM. Also stores the two lab credentials and lets the host's WinRM client talk to the lab.
# Run on the HOST in an ELEVATED PowerShell (Claude launches it with a UAC prompt).
# Same as: New VM + install Windows Server from the ISO by hand (language, edition "Standard Evaluation (Desktop Experience)",
# disk, admin password), then Settings > Network > static IP 192.168.100.11 / DNS 192.168.100.10, computer name CM01.
#
# Credentials (never printed, never in a repo):
#   %USERPROFILE%\.homelab\lab-admin.xml        LAB\Administrator, typed into a Windows password box (Get-Credential)
#   %USERPROFILE%\.homelab\cm01-local-admin.xml CM01's local Administrator, a random 24-char password generated here
#   Both are Export-Clixml files: Windows DPAPI encrypts the password so only your Windows account can read it back.
#   To see the CM01 local password yourself:  (Import-Clixml $env:USERPROFILE\.homelab\cm01-local-admin.xml).GetNetworkCredential().Password
# Host change: WinRM client TrustedHosts += 192.168.100.10, 192.168.100.11 (lets this PC use PowerShell remoting to the two lab
# servers by IP; the host is not in the domain, so Kerberos can't vouch for them). Undo: Set-Item WSMan:\localhost\Client\TrustedHosts ''.
# Sources (read 2026-11-05): Learn "Capture and apply Windows using a WIM file", "UEFI/GPT-based hard drive partitions";
# unattend components Microsoft-Windows-Shell-Setup / -TCPIP / -DNS-Client / -International-Core (Unattended Windows Setup Reference).
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'claude-elevated.log'
Start-Transcript -Path $log -Force | Out-Null
try {
    $vms    = 'D:\home-lab\vms'
    $vhd    = "$vms\CM01.vhdx"
    $mac    = '00155D640B11'                 # fixed MAC so the unattend's static IP binds to the right adapter
    $macDsh = '00-15-5D-64-0B-11'
    if (Get-VM -Name CM01 -ErrorAction SilentlyContinue) { throw 'A VM called CM01 already exists.' }
    # Re-run safety: a failed earlier run can leave the ISO and a half-built CM01.vhdx mounted on the host (2026-11-05: first run
    # failed writing unattend.xml because a freshly applied image has no Windows\Panther folder yet).
    $iso = Get-ChildItem 'D:\home-lab\iso\*SERVER_EVAL*.iso' | Select-Object -First 1
    if ((Get-DiskImage -ImagePath $iso.FullName).Attached) { Dismount-DiskImage -ImagePath $iso.FullName | Out-Null }
    if (Test-Path $vhd) {
        if ((Get-VHD -Path $vhd).Attached) { Dismount-VHD -Path $vhd }
        Remove-Item $vhd -Force; "Removed the half-built $vhd left by an earlier failed run."
    }

    # --- 1. Credentials --------------------------------------------------------------------------
    $sec = Join-Path $env:USERPROFILE '.homelab'
    New-Item -ItemType Directory -Force $sec | Out-Null
    if (-not (Test-Path "$sec\lab-admin.xml")) {
        Get-Credential -UserName 'LAB\Administrator' -Message 'LAB\Administrator password (stored encrypted for your Windows account only)' |
            Export-Clixml "$sec\lab-admin.xml"
    }
    $lab = Import-Clixml "$sec\lab-admin.xml"
    $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    $localPw = (-join (1..20 | ForEach-Object { $chars | Get-Random })) + 'a7Q!'
    $local = New-Object PSCredential('Administrator', (ConvertTo-SecureString $localPw -AsPlainText -Force))
    $local | Export-Clixml "$sec\cm01-local-admin.xml"
    "Credentials stored in $sec (DPAPI)."

    # --- 2. WinRM client: trust the two lab servers by IP ---------------------------------------
    Set-Service WinRM -StartupType Manual; Start-Service WinRM
    $th = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    $want = @('192.168.100.10', '192.168.100.11') | Where-Object { $th -notmatch [regex]::Escape($_) }
    if ($want) { Set-Item WSMan:\localhost\Client\TrustedHosts -Value ((@($th) + $want | Where-Object { $_ }) -join ',') -Force }
    "TrustedHosts: $((Get-Item WSMan:\localhost\Client\TrustedHosts).Value)"
    # Prove the stored LAB\Administrator password works before building anything on it
    $dc = Invoke-Command -ComputerName 192.168.100.10 -Credential $lab -ScriptBlock { "$env:COMPUTERNAME $((Get-CimInstance Win32_ComputerSystem).Domain)" }
    "DC01 answered over WinRM as LAB\Administrator: $dc"

    # --- 3. Free RAM: PC01 is done for now ---------------------------------------------------------
    if ((Get-VM PC01 -ErrorAction SilentlyContinue).State -eq 'Running') { Stop-VM -Name PC01; 'PC01 shut down (graceful) to free 4 GB.' }

    # --- 4. Apply Server 2025 to a new disk --------------------------------------------------------
    $isoDrive = (Mount-DiskImage -ImagePath $iso.FullName -PassThru | Get-Volume).DriveLetter
    $wim = "${isoDrive}:\sources\install.wim"
    Get-WindowsImage -ImagePath $wim | Format-Table ImageIndex, ImageName -AutoSize | Out-String
    $img = Get-WindowsImage -ImagePath $wim | Where-Object { $_.ImageName -match 'Standard' -and $_.ImageName -match 'Desktop' } | Select-Object -First 1
    if (-not $img) { throw 'No "Standard ... (Desktop Experience)" image in install.wim.' }
    "Applying: [$($img.ImageIndex)] $($img.ImageName)"

    New-VHD -Path $vhd -SizeBytes 150GB -Dynamic | Out-Null
    $diskNum = (Mount-VHD -Path $vhd -Passthru | Get-Disk).Number
    $used = (Get-Volume).DriveLetter + (Get-PSDrive -PSProvider FileSystem).Name
    $free = [char[]]'RSTUVWYZPQOLMN' | Where-Object { $used -notcontains $_ }
    $S, $W = $free[0], $free[1]
    # Microsoft's UEFI layout (300 MB system, 16 MB MSR, Windows); no recovery partition on a lab server
    @"
select disk $diskNum
convert gpt
create partition efi size=300
format quick fs=fat32 label="System"
assign letter="$S"
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
assign letter="$W"
exit
"@ | Set-Content "$env:TEMP\cm01-diskpart.txt" -Encoding ascii
    diskpart /s "$env:TEMP\cm01-diskpart.txt" | Out-String

    Expand-WindowsImage -ImagePath $wim -Index $img.ImageIndex -ApplyPath "${W}:\" | Out-Null
    "Image applied to ${W}:. System partition ${S}:."
    # bcdboot: use the HOST's own bcdboot.exe. The image's copy (Server 2025) run on this Windows 11 host failed silently, with and
    # without /offline (exit 0xC0E90002, empty ESP, VM: "The boot loader did not load an operating system"); the host's worked. See 43a.
    $ErrorActionPreference = 'Continue'
    & "$env:SystemRoot\System32\bcdboot.exe" "${W}:\Windows" /s "${S}:" /f UEFI 2>&1 | Select-Object -Last 2 | Out-String
    $ErrorActionPreference = 'Stop'
    if (-not (Test-Path "${S}:\EFI\Microsoft\Boot\BCD")) { throw 'bcdboot did not create the boot files.' }

    # --- 5. unattend.xml: name, static IP, DNS, locale, admin password, no OOBE questions ------------
    $pwXml = [System.Security.SecurityElement]::Escape($localPw)
    $c = 'processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"'
    @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" $c>
      <ComputerName>CM01</ComputerName>
      <TimeZone>Eastern Standard Time</TimeZone>
    </component>
    <component name="Microsoft-Windows-TCPIP" $c>
      <Interfaces>
        <Interface wcm:action="add">
          <Identifier>$macDsh</Identifier>
          <Ipv4Settings><DhcpEnabled>false</DhcpEnabled></Ipv4Settings>
          <UnicastIpAddresses><IpAddress wcm:action="add" wcm:keyValue="1">192.168.100.11/24</IpAddress></UnicastIpAddresses>
          <Routes><Route wcm:action="add"><Identifier>0</Identifier><Prefix>0.0.0.0/0</Prefix><NextHopAddress>192.168.100.1</NextHopAddress><Metric>10</Metric></Route></Routes>
        </Interface>
      </Interfaces>
    </component>
    <component name="Microsoft-Windows-DNS-Client" $c>
      <Interfaces>
        <Interface wcm:action="add">
          <Identifier>$macDsh</Identifier>
          <DNSServerSearchOrder><IpAddress wcm:action="add" wcm:keyValue="1">192.168.100.10</IpAddress></DNSServerSearchOrder>
        </Interface>
      </Interfaces>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" $c>
      <InputLocale>en-US</InputLocale><SystemLocale>en-US</SystemLocale><UILanguage>en-US</UILanguage><UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" $c>
      <UserAccounts><AdministratorPassword><Value>$pwXml</Value><PlainText>true</PlainText></AdministratorPassword></UserAccounts>
      <OOBE><HideEULAPage>true</HideEULAPage></OOBE>
    </component>
  </settings>
</unattend>
"@ | Set-Content (Join-Path (New-Item -ItemType Directory -Force "${W}:\Windows\Panther").FullName 'unattend.xml') -Encoding utf8
    'unattend.xml written (password inside is deleted later by script 44).'

    Dismount-VHD -Path $vhd
    Dismount-DiskImage -ImagePath $iso.FullName | Out-Null

    # --- 6. The VM -----------------------------------------------------------------------------------
    # Dynamic RAM: starts at 8 GB, Hyper-V gives it up to 12 GB under load and takes it back down to 4 GB idle.
    # Learn's lab spec for a site + database server is 8-12 GB. SQL Server's max memory gets capped later so it can't grab it all.
    New-VM -Name CM01 -Generation 2 -MemoryStartupBytes 8GB -VHDPath $vhd -SwitchName 'LabNAT' | Out-Null
    Set-VMMemory    -VMName CM01 -DynamicMemoryEnabled $true -MinimumBytes 4GB -StartupBytes 8GB -MaximumBytes 12GB
    Set-VMProcessor -VMName CM01 -Count 4
    Set-VM          -Name CM01 -AutomaticCheckpointsEnabled $false
    Set-VMNetworkAdapter -VMName CM01 -StaticMacAddress $mac
    Enable-VMIntegrationService -VMName CM01 -Name 'Guest Service Interface'
    foreach ($v in 'REF01', 'PC01') { Get-VMHardDiskDrive -VMName $v -ErrorAction SilentlyContinue | Where-Object Path -like '*images.vhdx' | Remove-VMHardDiskDrive }
    Add-VMHardDiskDrive -VMName CM01 -Path "$vms\images.vhdx" -ControllerLocation 1     # ref.wim rides along as a data disk
    Set-VMFirmware -VMName CM01 -FirstBootDevice (Get-VMHardDiskDrive -VMName CM01 -ControllerLocation 0)
    Start-VM -Name CM01
    Get-VMMemory CM01 | Format-Table VMName, DynamicMemoryEnabled, @{n='StartGB';e={$_.Startup/1GB}}, @{n='MinGB';e={$_.Minimum/1GB}}, @{n='MaxGB';e={$_.Maximum/1GB}} -AutoSize | Out-String
    'DONE: CM01 is booting (specialize + OOBE from unattend, ~5 min).'
}
catch {
    "FAILED: $($_.Exception.Message)"; $_.ScriptStackTrace
    # leave nothing mounted on the host after a failure
    if ($vhd -and (Test-Path $vhd) -and (Get-VHD -Path $vhd).Attached) { Dismount-VHD -Path $vhd; 'CM01.vhdx dismounted.' }
    if ($iso -and (Get-DiskImage -ImagePath $iso.FullName).Attached) { Dismount-DiskImage -ImagePath $iso.FullName | Out-Null; 'ISO dismounted.' }
}
finally { Stop-Transcript | Out-Null }
