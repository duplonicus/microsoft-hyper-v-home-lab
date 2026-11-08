# 31a - Checkpoint REF01 AFTER Sysprep has shut it down: a frozen, generalized REF01 to roll back to if the capture boot goes wrong.
# Run on the HOST in an Administrator PowerShell, once REF01 is Off after 31 (Sysprep). Same as Hyper-V Manager: REF01 > Checkpoint.
# Why (after a missed DVD boot sent REF01 into OOBE): rolling back to "before Sysprep" also means
# running Sysprep again; rolling back to "after Sysprep" is just Apply + boot again. The VM is off, so this is a pure disk-state copy.
$ErrorActionPreference = 'Stop'

if ((Get-VM -Name REF01).State -ne 'Off') { throw 'REF01 is not off. Wait for Sysprep to shut it down.' }
Get-VMSnapshot -VMName REF01 -Name 'after Sysprep' -ErrorAction SilentlyContinue | Remove-VMSnapshot   # replace an older one
Checkpoint-VM -Name REF01 -SnapshotName 'after Sysprep'

Get-VMSnapshot -VMName REF01 | Format-Table Name, SnapshotType, CreationTime
