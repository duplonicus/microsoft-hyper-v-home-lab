# 26b - run one of the lab scripts INSIDE a VM from the host, with no copy-paste and no network.
# Uses Hyper-V PowerShell Direct (Invoke-Command -VMName): PowerShell goes over the VM bus, so it works on any switch,
# with no RDP, no firewall rule, no SSH server in the VM. The script file is read on the host and its output comes back here.
# Run on the HOST in an Administrator PowerShell (Hyper-V admin). Examples, from this scripts folder:
#   .\26b-run-in-vm.ps1 REF01 28                      -> runs 28-ref01-apps-and-image-disk.ps1 inside REF01 as Administrator
#   .\26b-run-in-vm.ps1 DC01 25 -User LAB\Administrator
# Requirements (Learn "Manage Windows virtual machines with PowerShell Direct", read 2026-11-05): VM running on this host,
# Windows 10/Server 2016+ guest, valid credentials for an account in the VM. A blank-password account: NOT tested.
# Not for: WinPE / Windows Setup (step 4, 5, 6 boot environments) or anything that needs the VM's screen.
param(
    [Parameter(Mandatory, Position = 0)][string]$VM,
    [Parameter(Mandatory, Position = 1)][string]$Script,   # a path, or just the number/prefix like 28 or 26a
    [string]$User = 'Administrator'
)
$ErrorActionPreference = 'Stop'

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path -LiteralPath $Script -PathType Leaf) {
    $path = (Resolve-Path -LiteralPath $Script).Path
} else {
    $hits = @(Get-ChildItem -LiteralPath $dir -Filter "$Script-*.ps1")
    if ($hits.Count -ne 1) { throw "Expected one script matching '$Script-*.ps1' in $dir, found $($hits.Count): $($hits.Name -join ', ')" }
    $path = $hits[0].FullName
}

if ((Get-VM -Name $VM).State -ne 'Running') { throw "$VM is not running." }
$cred = Get-Credential -UserName $User -Message "Password for $User INSIDE $VM"

"Running $(Split-Path -Leaf $path) inside $VM as $User ..."
Invoke-Command -VMName $VM -Credential $cred -FilePath $path
