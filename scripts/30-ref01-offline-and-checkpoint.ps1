# 30 - Take REF01 off the network and checkpoint it, right before Sysprep. Run on the HOST in an Administrator PowerShell.
# Same as: VM Settings > Network Adapter > Virtual switch: Not connected; then Action > Checkpoint (named "before Sysprep").
# Why offline: Store apps updating themselves mid-way is the classic Sysprep failure (Learn "Sysprep (Generalize) a Windows
# installation"); with no network they can't. Sysprep and the capture don't need the network.
# Why a checkpoint: if Sysprep fails, Apply this checkpoint = back to a clean pre-Sysprep REF01 in a minute, instead of a reinstall.
# Delete the checkpoint once ref.wim is captured and checked (it's only an undo point).
$ErrorActionPreference = 'Stop'

Disconnect-VMNetworkAdapter -VMName REF01
Checkpoint-VM -Name REF01 -SnapshotName 'before Sysprep'

Get-VMNetworkAdapter -VMName REF01 | Format-Table VMName, SwitchName, Connected
Get-VMSnapshot -VMName REF01 | Format-Table Name, SnapshotType, CreationTime
