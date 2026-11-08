# 03 - after 02's reboot: confirm the rename, time zone and activation took.
# Expect: DC01, Eastern Standard Time, and an expiry about 180 days out.
hostname
(Get-TimeZone).Id
cscript //nologo $env:windir\System32\slmgr.vbs /xpr
