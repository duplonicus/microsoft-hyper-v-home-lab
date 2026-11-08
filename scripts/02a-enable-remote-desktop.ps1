# 02a - turn on Remote Desktop inside DC01, which Hyper-V's Enhanced Session (and its shared clipboard) needs.
# Run INSIDE DC01 in an Administrator PowerShell. Same as Settings > System > Remote Desktop > On.
# It is off on a fresh Server install. The clipboard only works after sign-in, so type the password by hand.
$ErrorActionPreference = 'Stop'

Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

(Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server').fDenyTSConnections  # 0 = on

# Windows Update has no built-in PowerShell cmdlet (it needs the PSWindowsUpdate module from the
# PowerShell Gallery), so updates were run by hand: Settings > Windows Update, until none are left.
