# 28 - Customize the reference PC: install lab apps silently from MSI, stamp an image version, format the image disk.
# Run INSIDE REF01 (Audit Mode, built-in Administrator) in an Administrator PowerShell.
# Same as: downloading three installers in a browser and clicking through them, making a shortcut on the Public desktop,
# and Disk Management > Initialize Disk (GPT) > New Simple Volume (I:, NTFS, "Images").
# Why MSI + /qn, not winget or the Store: silent, repeatable installs are how apps go into a lab image (or SCCM/Intune later),
# and Store/App Installer updates are the classic Sysprep breaker. Links checked 2026-11-05 (Google, 7-zip.org -> GitHub, VideoLAN).
# Safe to re-run (it was, after the VLC fix): msiexec skips an installed product; the disk step only touches a RAW (never-initialized) disk.
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # the progress bar makes Invoke-WebRequest many times slower in PowerShell 5.1

$dl = 'C:\Temp\installers'
New-Item -ItemType Directory -Force $dl, 'C:\Temp\logs' | Out-Null

$apps = [ordered]@{
    'Chrome' = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'
    '7-Zip'  = 'https://github.com/ip7z/7zip/releases/download/26.05/7z2605-x64.msi'
    # ?direct: without it VideoLAN sends PowerShell's user agent an HTML "download is starting" page, not the file
    # (first run 2026-11-05: VLC exit code 1620 = "package could not be opened"; Claude compared both user agents with curl)
    'VLC'    = 'https://get.videolan.org/vlc/3.0.24/win64/vlc-3.0.24-win64.msi?direct'
}

foreach ($name in $apps.Keys) {
    $msi = Join-Path $dl "$name.msi"
    "Downloading $name..."
    Invoke-WebRequest $apps[$name] -OutFile $msi -UseBasicParsing
    # Every real MSI starts with the same 4 bytes (D0 CF 11 E0, the OLE compound-file header). A web page doesn't.
    $head = [System.IO.File]::ReadAllBytes($msi)[0..3] | ForEach-Object { $_.ToString('X2') }
    if (($head -join ' ') -ne 'D0 CF 11 E0') { throw "$name download is not an MSI (starts with $($head -join ' ')); probably an HTML page" }
    # /qn = no UI at all, /norestart = never reboot by itself, /l*v = full log (where you look when an install fails)
    $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList '/i', "`"$msi`"", '/qn', '/norestart', '/l*v', "`"C:\Temp\logs\$name.log`""
    "$name exit code: $($p.ExitCode)  (0 = OK, 3010 = OK but wants a reboot)"
}

# Image version stamp: lets anyone check which image a lab PC was built from
"Win11-Ref-v1 built $(Get-Date -Format yyyy-MM-dd) (lab.dupnet.internal home lab)" | Set-Content C:\LabImage-v1.txt
# A shortcut on the PUBLIC desktop, so every user who signs in later sees it (a visible proof the customization survived)
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut('C:\Users\Public\Desktop\Lab image version.lnk')
$lnk.TargetPath = 'C:\Windows\System32\notepad.exe'
$lnk.Arguments  = 'C:\LabImage-v1.txt'
$lnk.Save()

# The 40 GB images.vhdx: initialize GPT, one NTFS volume, letter I:, label Images
Get-Disk | Where-Object PartitionStyle -eq 'RAW' |
    Initialize-Disk -PartitionStyle GPT -PassThru |
    New-Partition -DriveLetter I -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel Images -Confirm:$false | Out-Null

# Clean up the installers so they aren't baked into the image (smaller .wim)
Remove-Item $dl -Recurse -Force

# Checks
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Where-Object DisplayName -match 'Chrome|7-Zip|VLC' | Format-Table DisplayName, DisplayVersion
Get-Volume -DriveLetter C, I | Format-Table DriveLetter, FileSystemLabel, FileSystem, @{n='SizeGB';e={[math]::Round($_.Size/1GB)}}
Get-Content C:\LabImage-v1.txt
