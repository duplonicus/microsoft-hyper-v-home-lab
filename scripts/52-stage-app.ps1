# 52 - Stage an MSI as ConfigMgr application content: download on the HOST, read its MSI properties, copy it into CM01's source share.
# Why: an Application's content must sit on a UNC path the site server can read (\\CM01\Sources = C:\Sources on CM01); ConfigMgr copies
# it from there into its content library and out to the DP. One folder per app VERSION, so the next version never overwrites this one.
# The MSI's ProductCode is what ConfigMgr uses as the detection method ("is this exact MSI installed?").
# Run on the HOST, not elevated. Downloads go via the host because lab VMs can't reliably reach the internet (NOW.md gotchas).
# Used for: PuTTY 0.85 (chiark "latest release (0.85)" page, 2026-11-07): the first app deployed by hand in the console. 7-Zip is already in
# ref.wim (26.05, script 28), so 7-Zip 26.06 (7-zip.org, released 2026-11-06) is staged too, for a later UPGRADE exercise.
param(
    [string]$Name    = 'PuTTY',
    [string]$Version = '0.85',
    [string]$Url     = 'https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.85-installer.msi'
)
$ErrorActionPreference = 'Stop'
$file  = ($Url -split '/')[-1] -replace '\?.*$', ''
$local = "D:\home-lab\apps\$Name\$Version"
New-Item -ItemType Directory -Path $local -Force | Out-Null
$msi = Join-Path $local $file
if (-not (Test-Path $msi)) { Invoke-WebRequest -Uri $Url -OutFile $msi -UseBasicParsing }
$head = [IO.File]::ReadAllBytes($msi)[0..3] | ForEach-Object { $_.ToString('X2') }
if (($head -join ' ') -ne 'D0 CF 11 E0') { throw "$file is not an MSI (starts with $($head -join ' '))" }
"Downloaded: $msi  ($((Get-Item $msi).Length) bytes)  SHA256 $((Get-FileHash $msi).Hash)"

# The same values ConfigMgr's Create Application wizard reads from the MSI.
$wi = New-Object -ComObject WindowsInstaller.Installer
$db = $wi.OpenDatabase($msi, 0)
foreach ($p in 'ProductName', 'ProductVersion', 'Manufacturer', 'ProductCode') {
    $v = $db.OpenView("SELECT Value FROM Property WHERE Property='$p'"); $v.Execute()
    "{0,-15} {1}" -f $p, $v.Fetch().StringData(1); $v.Close()
}
$sig = Get-AuthenticodeSignature $msi
"Signature       $($sig.Status)  $($sig.SignerCertificate.Subject)"

$lab = Import-Clixml "$env:USERPROFILE\.homelab\lab-admin.xml"
$s = New-PSSession -ComputerName 192.168.100.11 -Credential $lab
try {
    $dest = "C:\Sources\Apps\$Name\$Version"
    Invoke-Command -Session $s -ScriptBlock { New-Item -ItemType Directory -Path $using:dest -Force | Out-Null }
    Copy-Item -Path $msi -Destination $dest -ToSession $s -Force
    Invoke-Command -Session $s -ScriptBlock {
        $share = Get-SmbShare -Name Sources
        "Share: \\CM01.lab.dupnet.internal\Sources -> $($share.Path)"
        "Wizard path: \\CM01.lab.dupnet.internal\Sources\Apps\$using:Name\$using:Version\$using:file"
        Get-ChildItem $using:dest | Format-Table Name, Length -AutoSize | Out-String
    }
} finally { Remove-PSSession $s }
