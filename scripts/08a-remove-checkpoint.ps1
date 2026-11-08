# 08a - delete the 'before AD DS' checkpoint once 08-check-dc.ps1 is clean. Run on the HOST in an Administrator PowerShell.
# Same as Hyper-V Manager > right-click the checkpoint > Delete Checkpoint.
# Deleting merges the .avhdx (everything written since the checkpoint) back into DC01.vhdx; never delete the .avhdx by hand.
# Don't keep old checkpoints of a DC around: rolling a DC back can confuse Active Directory.
$ErrorActionPreference = 'Stop'

Remove-VMCheckpoint -VMName DC01 -Name 'before AD DS'
Get-VMCheckpoint -VMName DC01   # nothing printed = no checkpoints left
