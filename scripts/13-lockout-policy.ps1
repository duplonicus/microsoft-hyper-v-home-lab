# 13 - turn on account lockout for the domain: 5 bad passwords locks an account for 10 minutes.
# Run INSIDE DC01 as LAB\Administrator in an Administrator PowerShell.
# A new lab.dupnet.internal domain came with LockoutThreshold 0 (= never locks), checked 2026-10-28.
# By hand this is a Group Policy edit: Group Policy Management > Default Domain Policy > Edit >
# Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Account Lockout Policy.
# Domain-wide account policies only take effect from a GPO linked at the domain (the Default Domain Policy)
# (CIS benchmark; fine-grained password policies are the exception).
# This cmdlet writes the same values straight onto the domain object instead. If the Default Domain Policy still
# said 0, a later policy refresh would likely put 0 back (inference from community sources, not verified), so the
# GPO edit is the one that counts; this script is for checking and for rebuilding the lab.
$ErrorActionPreference = 'Stop'

$domain = (Get-ADDomain).DNSRoot
Set-ADDefaultDomainPasswordPolicy -Identity $domain -LockoutThreshold 5 `
    -LockoutDuration '00:10:00' -LockoutObservationWindow '00:10:00'

Get-ADDefaultDomainPasswordPolicy | Format-List LockoutThreshold, LockoutDuration, LockoutObservationWindow
