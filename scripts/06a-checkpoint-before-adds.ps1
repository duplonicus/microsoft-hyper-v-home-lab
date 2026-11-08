# 06a - checkpoint DC01 before the promotion, so a bad promotion is one click to undo.
# Run on the HOST in an Administrator PowerShell. Same as Hyper-V Manager > right-click DC01 > Checkpoint, then Rename.
# Production checkpoint (the default): VSS inside the VM, no memory saved.
# Next: 07-promote-dc.ps1. Delete the checkpoint with 08a once 08-check-dc.ps1 is clean.
$ErrorActionPreference = 'Stop'

Checkpoint-VM -Name DC01 -SnapshotName 'before AD DS'
Get-VMCheckpoint -VMName DC01 | Format-Table Name, CheckpointType, CreationTime
