# 43a - Fix CM01's boot files. Run on the HOST in an ELEVATED PowerShell (UAC), with CM01 off (this turns it off).
# Why: after 43, CM01's firmware said "The boot loader did not load an operating system" for its disk, and 43's bcdboot step
# had printed nothing (so it most likely failed without a visible error). Learn "BCDBoot command-line options": run in a normal
# Windows session, bcdboot chooses which boot files to copy based on the machine it RUNS on; /offline ("forces boot file servicing
# to be handled in an offline manner", Windows 11 24H2 build 26100.8037 and later) is for preparing a disk that boots elsewhere.
# /s without NVRAM: with /s, bcdboot creates no firmware entry on this host (Learn), so the host's own boot menu is untouched.
# Same as: booting CM01 from the Server ISO, Shift+F10, bcdboot C:\Windows /s S: /f UEFI.
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'claude-elevated.log'
Start-Transcript -Path $log -Force | Out-Null
$vhd = 'D:\home-lab\vms\CM01.vhdx'
try {
    if ((Get-VM CM01).State -ne 'Off') { Stop-VM -Name CM01 -TurnOff -Force; 'CM01 turned off.' }
    $disk  = Mount-VHD -Path $vhd -Passthru | Get-Disk
    $parts = $disk | Get-Partition
    $esp   = $parts | Where-Object GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
    $win   = $parts | Where-Object { $_.Type -eq 'Basic' } | Sort-Object Size -Descending | Select-Object -First 1
    foreach ($p in $esp, $win) { if (-not $p.DriveLetter) { $p | Add-PartitionAccessPath -AssignDriveLetter } }
    $S = ($esp | Get-Partition).DriveLetter; $W = ($win | Get-Partition).DriveLetter
    "ESP = ${S}:   Windows = ${W}:   Windows folder present: $(Test-Path "${W}:\Windows\System32\winload.efi")"

    '--- ESP before ---'
    Get-ChildItem "${S}:\" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 15 | ForEach-Object { $_.FullName.Substring(3) }

    # First run of 43a (2026-11-05): the IMAGE's bcdboot with /offline exited -1058471934 (0xC0E90002), no output, ESP still empty.
    # So try, in order: the HOST's own bcdboot, then the image's copy without /offline. Stop at the first that fills the ESP.
    $ErrorActionPreference = 'Continue'   # PowerShell 5.1 turns a native program's stderr into errors; don't let that abort the run
    $tries = @(
        @{ name = 'host bcdboot';               exe = "$env:SystemRoot\System32\bcdboot.exe"; extra = @() },
        @{ name = 'image bcdboot, no /offline'; exe = "${W}:\Windows\System32\bcdboot.exe";  extra = @() }
    )
    foreach ($t in $tries) {
        "--- $($t.name) ---"
        $out = & $t.exe "${W}:\Windows" /s "${S}:" /f UEFI /v @($t.extra) 2>&1
        $out | Out-String
        "exit code: $LASTEXITCODE (0x{0:X8})" -f $LASTEXITCODE
        if (Test-Path "${S}:\EFI\Microsoft\Boot\BCD") { "boot files written by: $($t.name)"; break }
    }

    '--- ESP after ---'
    foreach ($f in 'EFI\Boot\bootx64.efi', 'EFI\Microsoft\Boot\bootmgfw.efi', 'EFI\Microsoft\Boot\BCD') {
        "{0,-36} {1}" -f $f, (Test-Path "${S}:\$f")
    }
    & bcdedit.exe /store "${S}:\EFI\Microsoft\Boot\BCD" /enum osloader 2>&1 | Select-String 'device|path|description' | Out-String
    $ErrorActionPreference = 'Stop'
}
catch { "FAILED: $($_.Exception.Message)"; $_.ScriptStackTrace }
finally {
    if ((Get-VHD -Path $vhd).Attached) { Dismount-VHD -Path $vhd; 'CM01.vhdx dismounted.' }
    if (-not $Error.Count -or (Test-Path variable:S)) {
        Set-VMFirmware -VMName CM01 -FirstBootDevice (Get-VMHardDiskDrive -VMName CM01 -ControllerLocation 0)
        Start-VM -Name CM01; 'CM01 started.'
    }
    Stop-Transcript | Out-Null
}
