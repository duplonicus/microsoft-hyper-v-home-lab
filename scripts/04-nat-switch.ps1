# 04 - fixed lab network. Run on the HOST (not in DC01) in an Administrator PowerShell.
# Creates an internal switch with a NAT behind it, so DC01 keeps one IP for good
# (the Default Switch's range can change when the host reboots).
# Steps from Microsoft Learn, "Set up a NAT network". Windows allows ONE NAT per host.
# Next: connect DC01 to LabNAT and give it 192.168.100.10.
$ErrorActionPreference = 'Stop'

$SwitchName = 'LabNAT'
$Gateway    = '192.168.100.1'
$Prefix     = '192.168.100.0/24'

# A second NAT leaves WinNAT in an "unknown state" (Learn), so stop if one exists
$existing = Get-NetNat
if ($existing) {
    throw "A NAT already exists on this PC: $($existing.Name). Not creating another one."
}

if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    New-VMSwitch -SwitchName $SwitchName -SwitchType Internal | Out-Null
}

# The host side of the switch is the lab's gateway
$ifIndex = (Get-NetAdapter -Name "vEthernet ($SwitchName)").ifIndex
if (-not (Get-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $Gateway -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -IPAddress $Gateway -PrefixLength 24 -InterfaceIndex $ifIndex | Out-Null
}

New-NetNat -Name $SwitchName -InternalIPInterfaceAddressPrefix $Prefix | Out-Null

# Show what was made
Get-VMSwitch -Name $SwitchName | Format-Table Name, SwitchType
Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 | Format-Table InterfaceAlias, IPAddress, PrefixLength
Get-NetNat | Format-Table Name, InternalIPInterfaceAddressPrefix, Active
