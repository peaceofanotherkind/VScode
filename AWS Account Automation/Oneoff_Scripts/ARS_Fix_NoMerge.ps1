Import-Module ActiveRolesManagementShell
$qadcred = get-credential
Connect-QADService -proxy -credential $qadcred

# This script gathers all BSAM_AWS groups and applies 'BSAM_IsNoMerge' attribute to prevent cloned users from getting automatically added to AWS groups. 
# Note - the bsam_isnomerge attribute does not exist on objects unless it is set at some point
# Searching on it being set to false my provide incomplete data

$ou = "bfusa.com/AdminDomain/Groups/Privileged Groups"

$awsgroups = get-qadgroup -sizelimit 0 -SearchRoot $OU | Where-Object {$_.Name -like "BSAM_AWS_*"}
foreach ($group in $awsgroups){
    Set-qADGroup $group -objectattributes @{bsam_isnomerge="True"}
}


Write-Output "List of all AWS Groups and merge setting (should all be True)"
get-qadgroup -sizelimit 0 -SearchRoot $OU | Where-Object {$_.Name -like "BSAM_AWS_*" -and $_.bsam_isnomerge -eq "True"} | select Name, bsam_isnomerge 

