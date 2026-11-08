# 50c - PC02 didn't finish its task sequence: turn it off, mount its disk READ-ONLY on the host, and copy out any task sequence logs.
# Why: WinPE keeps smsts.log on X: (a RAM disk) until the TS has a formatted disk, so a reboot loses it unless the TS got as far as
# partitioning (then it lives in C:\_SMSTaskSequence\Logs or a staged boot image). The disk tells us how far the TS got.
# Run on the HOST in an ELEVATED PowerShell (Claude launches it with a UAC prompt). Copies land in %TEMP%\pc02-tslogs.
# Same as: Hyper-V Manager > PC02 > Turn Off; Disk Management > Action > Attach VHD (read-only); browse the new drive; Detach VHD.
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'claude-elevated.log'
Start-Transcript -Path $log -Force | Out-Null
$vhd = 'D:\home-lab\vms\PC02.vhdx'
$out = Join-Path $env:TEMP 'pc02-tslogs'
try {
    if ((Get-VM PC02).State -ne 'Off') { Stop-VM -Name PC02 -TurnOff -Force; 'PC02 turned off.' }
    $d = Mount-VHD -Path $vhd -ReadOnly -Passthru | Get-Disk
    "Disk partition style: $($d.PartitionStyle)   size: $([math]::Round($d.Size/1GB)) GB"
    Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Format-Table PartitionNumber, Type, @{n='GB';e={[math]::Round($_.Size/1GB,1)}}, DriveLetter -AutoSize | Out-String
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    foreach ($p in Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue) {
        $path = ($p.AccessPaths | Where-Object { $_ -like '\\?\Volume*' } | Select-Object -First 1)
        if (-not $path) { continue }
        "--- partition $($p.PartitionNumber) top level:"
        Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        Get-ChildItem -LiteralPath $path -Recurse -Force -Include 'smsts*.log','tspxe*.log' -ErrorAction SilentlyContinue | ForEach-Object {
            $dest = Join-Path $out ("p$($p.PartitionNumber)-" + $_.Name); Copy-Item -LiteralPath $_.FullName -Destination $dest -Force; "copied: $($_.FullName) -> $dest"
        }
    }
}
catch { "FAILED: $($_.Exception.Message)" }
finally { Dismount-VHD -Path $vhd -ErrorAction SilentlyContinue; 'disk detached.'; Stop-Transcript | Out-Null }
