#param([System.String]$groupname)
Write-Host "This script will add a newly created AD group to the AWS SSO app in Azure"
Write-Host "You will need to provide the account name and then role in seperate prompts"
Write-Host "The Script will format the group name based on your input automatically(BSAM_AWS_Accountname_Rolename format)"
$accountname = Read-Host "Please enter the account name (Such as BrandsDam):"
$rolename = Read-host "Please enter the role name (such as ReadOnly or Developer_Read)"
$groupname = "BSAM_AWS_"+ $accountname + "_$rolename"
Import-Module ActiveRolesManagementShell
Write-Host "`n Please sign in using your a-account.  This is for ARS connectivity`n"
$qadcred = get-credential
Connect-QADService -proxy -credential $qadcred

$ou = "bfusa.com/AdminDomain/Groups/Privileged Groups"
$type = "Security"
$scope = "Global"
$managedby = "BSA-IT-ICE-Admins"
$description = "AWS access group"

$GroupPresent = Get-qADGroup -Name $groupname | select Name -ExpandProperty Name
    If (!$GroupPresent){
    Write-Output "$groupname not present, creating..."
    New-qADGroup -ParentContainer $ou -Name $groupname -DisplayName $groupname -Description $description -GroupScope $scope -GroupType $type -ManagedBy $managedby -ManagerCanUpdateMembershipList $true
    Set-qADGroup $groupname -objectattributes @{extensionAttribute12="BSAM"}
    Set-qADObject $groupname -objectattributes @{edsvaProtectFromDeletion=$True}
    Set-qADGroup $groupname -objectattributes @{bsam_isnomerge="True"}
    }
    Else {
    Write-Output "$groupname already exists!"
    }

Write-Output "`n `n*******************IMPORTANT - PLEASE READ!*******************`n `n"
Write-Output "*****Group creation and existence verification completed******`n `n"
Write-Output "***Script pausing 2h for sync - DO NOT CLOSE THIS WINDOW!!!***`n `n"
Write-Output "******Expect Azure Credential screen when pause concludes*****`n `n"
Get-Date
Start-Sleep -Seconds 7200
Write-Output "`n `n *******Script resuming, Installing Azure AD Module******`n `n"
Install-Module AzureAD -force
################################################################################
################################################################################
Write-Output "`n `n ***********Input Azure credentials in prompt************`n `n"
Connect-AzureAD

$app_name = "SSO_BSAM_AWS"
$app_role_name = "User"
$sp = Get-AzureADServicePrincipal -Filter "displayName eq '$app_name'"
$appRole = $sp.AppRoles | Where-Object { $_.DisplayName -eq $app_role_name }

$group = Get-AzureADGroup -Filter "displayName eq '$groupname'"
    if (!$group){
    Write-Output "The read-only not present yet, sleeping another 1hr"
    Write-Output "`n `n******Expect Azure Credential screen when pause concludes*****`n `n"
    Start-Sleep -Seconds 3600
    Write-Output "`n `n*******Script resuming, load Azure credentials in prompt******`n `n"
    Connect-AzureAD
    $group = Get-AzureADGroup -Filter "displayName eq '$groupname'"
        if (!$group){
        Write-Output "$group not present after 3+ hours, please investigate! Script Exiting"
        Exit-PSSession
        }
        Else {
            Write-Output "`n The read-only group is present in Azure AD, checking/adding group role assignment..."
            $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $group.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
            If ($RoleStatus -ne "$app_name"){
                Write-Output "`n Adding `n Azure AD role assignment of $app_name for the read-only group"
                New-AzureADGroupAppRoleAssignment -objectid $group.ObjectId -Principalid $group.Objectid -resourceid $sp.Objectid -id $appRole.id
            }
            Else {
            Write-Output "`n Azure AD role assignment of $app_name for the read-only group is already present"
            }
        }
    }
    Else {
        Write-Output "`n The read-only group is present in Azure AD, checking/adding group role assignment..."
        $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $group.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
        If ($RoleStatus -ne "$app_name"){
           Write-Output "`n Adding `n Azure AD role assignment of $app_name for the read-only group"
           New-AzureADGroupAppRoleAssignment -objectid $group.ObjectId -Principalid $group.Objectid -resourceid $sp.Objectid -id $appRole.id
        }
        Else {
           Write-Output "`n Azure AD role assignment of $app_name for the read-only group is already present"
        }
    }

$NameFormatted = $Group.DisplayName
Write-Output "`n `n*******************CONGRATULATIONS*******************`n `n"
Write-Output "Group $NameFormatted has been created/verified in ARS `n `n"
Write-Output "Group has syned to Azure AD and have their roles assigned"
Write-Output "`n Wait up to 40 minutes for the sync to occur from Azure AD to AWS"