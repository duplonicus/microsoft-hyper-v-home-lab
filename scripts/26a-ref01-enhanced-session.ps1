# 26a - make Hyper-V Enhanced Session (shared clipboard, resizable window) work on REF01 in Audit Mode.
# Run INSIDE REF01 (Audit Mode, built-in Administrator) in an Administrator PowerShell, in the BASIC session
# (VMConnect menu Clipboard > Type clipboard text types the first two commands for you).
# Same as Settings > System > Remote Desktop > On, plus setting a password on the built-in Administrator.
# Two reasons it doesn't work out of the box:
#  1. Enhanced Session is RDP over the VM bus, and Remote Desktop is off on a fresh Windows install (same as DC01, scripts/02a).
#  2. Audit Mode signs in as the built-in Administrator with a BLANK password, and Windows' default policy
#     "Accounts: Limit local account use of blank passwords to console logon only" (Enabled) refuses blank-password
#     logons over Remote Desktop. Enhanced Session counts as one, so it needs a password.
# Lab-only password; don't reuse a real one. It is TEMPORARY: step 3 blanks it again right before Sysprep (net user Administrator "").
# Why: Sysprep /generalize DISABLES the built-in Administrator on next start, but on client editions it does NOT clear its password
# (only server editions get it cleared). Left in, every PC from this image would share one known admin password the moment anyone
# re-enabled the account. Production answer: Windows LAPS gives each PC its own rotating local admin password.
# Source: Learn "Enable and Disable the Built-in Administrator Account" + "Windows LAPS overview" (both read 2026-11-05).
$ErrorActionPreference = 'Stop'

Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
(Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server').fDenyTSConnections  # 0 = on

# Typed by hand in the session (an interactive prompt would swallow anything typed after it):
#   net user Administrator *
