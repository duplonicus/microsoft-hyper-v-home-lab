# 18b - keep DC01 at 4 GB or more, the Cloud Sync agent's stated minimum. Run on the HOST in an Administrator PowerShell.
# Same as Hyper-V Manager > DC01 > Settings > Memory > Minimum RAM: 4096 MB (dynamic memory stays on).
# Why: with dynamic memory DC01 had shrunk to 2.9 GB while idle (2026-10-28). Raising the minimum stops that;
# the maximum still lets it grow. Changing the minimum works while DC01 runs.
$ErrorActionPreference = 'Stop'

Set-VMMemory -VMName DC01 -MinimumBytes 4GB
Get-VMMemory -VMName DC01 | Format-List DynamicMemoryEnabled,
    @{ n = 'StartupMB'; e = { $_.Startup / 1MB } }, @{ n = 'MinimumMB'; e = { $_.Minimum / 1MB } }, @{ n = 'MaximumMB'; e = { $_.Maximum / 1MB } }
