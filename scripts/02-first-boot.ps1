# 02 - first boot of DC01. Run inside the VM in an Administrator PowerShell.
# Checks internet, activates the evaluation, sets the time zone, renames the server, then reboots.
# Next: 03-check-first-boot.ps1 after the reboot.
$ErrorActionPreference = 'Stop'

# Internet through the Default Switch; activation needs it
if (-not (Test-NetConnection microsoft.com -Port 443).TcpTestSucceeded) {
    throw 'No internet from the VM (port 443 to microsoft.com failed). Check the VM network switch.'
}

# Activate the evaluation online (Microsoft: within 10 days or it starts shutting down).
# cscript prints to this window and waits, unlike plain slmgr, which pops up a box and returns at once.
cscript //nologo $env:windir\System32\slmgr.vbs /ato
cscript //nologo $env:windir\System32\slmgr.vbs /xpr

Set-TimeZone -Id 'Eastern Standard Time'

# Rename from the random WIN-XXXX name; takes effect after the restart
Rename-Computer -NewName DC01 -Restart
