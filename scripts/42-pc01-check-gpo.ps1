# 42 - Prove part 1's Group Policy reaches a real client: PC01, signed in as a Staff user. Run INSIDE PC01 in a NORMAL
# (non-admin) PowerShell as the Staff user (gpresult /r shows the signed-in user's policy). Type it, or push with 26c first.
# Same as: Command Prompt > gpupdate /force, gpresult /r; then trying to open Control Panel (Staff - Block Control Panel GPO).
# Closes part 1's open item (HOME-LAB.md section 3 had no client to test on; GPO was only proven via Group Policy Modeling).
(Get-CimInstance Win32_ComputerSystem) | Format-List Name, Domain, PartOfDomain   # PC01 / lab.dupnet.internal / True
whoami                                                                             # LAB\<user>
gpupdate /force
gpresult /r /scope user          # look for "Staff - Block Control Panel" under Applied Group Policy Objects
control                          # should be refused: "This operation has been cancelled due to restrictions..."
