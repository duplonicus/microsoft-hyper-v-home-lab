# 24 - add Microsoft Teams to the existing Sales Team M365 group. Run on the HOST in PowerShell, not on DC01.
# Done by hand 2026-10-29 in the Teams app: Create team > More create team options > From a group (it only lists
# groups you own; admin@ was an owner then). This is the admin route that doesn't need ownership.
# The team keeps the group's dynamic membership and its owner.
# Needs the module once: Install-Module MicrosoftTeams -Scope CurrentUser
param([Parameter(Mandatory)][string]$GroupId)   # Sales Team's Object ID, from Entra > Groups > Overview > Object ID

Import-Module MicrosoftTeams
Connect-MicrosoftTeams
New-Team -GroupId $GroupId
Get-Team -GroupId $GroupId | Select-Object DisplayName, Visibility, GroupId
