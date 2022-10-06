#param([System.String]$accountname)

Write-Host "`n This script handles two portions of the Groups creation process `n"
Write-Host "First: This script will create the ReadOnly and PowerUsers AD groups for new AWS accounts `n"
Write-Host "Second: This script will handle the Azure AD role assigment to the AD group once synced `n"
Write-Host " `n `n You only need to provide the AWS account name assigned"
$accountname = Read-Host "Please enter the AWS account name (BrandsDAM, for example):"
Import-Module ActiveRolesManagementShell
Write-Host "`n Please sign in using your a-account.  This is for ARS connectivity`n"
$qadcred = get-credential
Connect-QADService -proxy -credential $qadcred

$ou = "bfusa.com/AdminDomain/Groups/Privileged Groups"
$name_ro = "BSAM_AWS`_$accountname`_Developer_Ext"
$name_pu = "BSAM_AWS`_$accountname`_Developer"
$name_bl = "BSAM_AWS`_$accountname`_Billing"
$type = "Security"
$scope = "Global"
$managedby = "BSA-IT-ICE-Admins"
$description_ro = "AWS Read Only access group for $accountname"
$description_pu = "AWS Power Users access group for $accountname"
$description_bl = "AWS Billing access group for $accountname"


$GroupROPresent = Get-qADGroup -Name $name_ro | select Name -ExpandProperty Name
    If (!$GroupROPresent){
    Write-Output "$name_ro not present, creating..."
    New-qADGroup -ParentContainer $ou -Name $name_ro -DisplayName $name_ro -Description $description_ro -GroupScope $scope -GroupType $type -ManagedBy $managedby -ManagerCanUpdateMembershipList $true
    Set-qADGroup $name_ro -objectattributes @{extensionAttribute12="BSAM"}
    Set-qADObject $name_ro -objectattributes @{edsvaProtectFromDeletion=$True}
    Set-qADGroup $name_ro -objectattributes @{bsam_isnomerge="True"}
    }
    Else {
    Write-Output "$name_ro already exists!"
    }

$GroupPUPresent = Get-qADGroup -Name $name_pu | select Name -ExpandProperty Name
    if (!$GroupPUPresent){
    Write-Output "$name_pu not present, creating..."
    New-qADGroup -ParentContainer $ou -Name $name_pu -DisplayName $name_pu -Description $description_pu -GroupScope $scope -GroupType $type -ManagedBy $managedby -ManagerCanUpdateMembershipList $true
    Set-qADGroup $name_pu -objectattributes @{extensionAttribute12="BSAM"}
    Set-qADObject $name_pu -objectattributes @{edsvaProtectFromDeletion=$True}
    Set-qADGroup $name_pu -objectattributes @{bsam_isnomerge="True"}
    }
    Else {
    Write-Output "$name_pu already exists!"
    }

    $GroupBLPresent = Get-qADGroup -Name $name_bl | select Name -ExpandProperty Name
    if (!$GroupblPresent){
    Write-Output "$name_bl not present, creating..."
    New-qADGroup -ParentContainer $ou -Name $name_bl -DisplayName $name_bl -Description $description_bl -GroupScope $scope -GroupType $type -ManagedBy $managedby -ManagerCanUpdateMembershipList $true
    Set-qADGroup $name_bl -objectattributes @{extensionAttribute12="BSAM"}
    Set-qADObject $name_bl -objectattributes @{edsvaProtectFromDeletion=$True}
    Set-qADGroup $name_bl -objectattributes @{bsam_isnomerge="True"}
    }
    Else {
    Write-Output "$name_bl already exists!"
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

$ROGroup = Get-AzureADGroup -Filter "displayName eq '$name_ro'"
    if (!$ROGroup){
    Write-Output "The read-only not present yet, sleeping another 1hr"
    Write-Output "`n `n******Expect Azure Credential screen when pause concludes*****`n `n"
    Start-Sleep -Seconds 3600
    Write-Output "`n `n*******Script resuming, load Azure credentials in prompt******`n `n"
    Connect-AzureAD
    $ROGroup = Get-AzureADGroup -Filter "displayName eq '$name_ro'"
        if (!$ROGroup){
        Write-Output "$ROgroup not present after 3+ hours, please investigate! Script Exiting"
        Exit-PSSession
        }
        Else {
            Write-Output "`n The read-only group is present in Azure AD, checking/adding group role assignment..."
            $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $ROgroup.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
            If ($RoleStatus -ne "$app_name"){
                Write-Output "`n Adding `n Azure AD role assignment of $app_name for the read-only group"
                New-AzureADGroupAppRoleAssignment -objectid $ROgroup.ObjectId -Principalid $ROgroup.Objectid -resourceid $sp.Objectid -id $appRole.id
            }
            Else {
            Write-Output "`n Azure AD role assignment of $app_name for the read-only group is already present"
            }
        }
    }
    Else {
        Write-Output "`n The read-only group is present in Azure AD, checking/adding group role assignment..."
        $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $ROgroup.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
        If ($RoleStatus -ne "$app_name"){
           Write-Output "`n Adding `n Azure AD role assignment of $app_name for the read-only group"
           New-AzureADGroupAppRoleAssignment -objectid $ROgroup.ObjectId -Principalid $ROgroup.Objectid -resourceid $sp.Objectid -id $appRole.id
        }
        Else {
           Write-Output "`n Azure AD role assignment of $app_name for the read-only group is already present"
        }
    }

$PUGroup = Get-AzureADGroup -Filter "displayName eq '$name_pu'"
    if (!$PUGroup){
    Write-Output "`n The power users not present yet, sleeping another 1hr"
    Write-Output "`n `n******Expect Azure Credential screen when pause concludes*****`n `n"
    Start-Sleep -Seconds 3600
    Write-Output "`n `n*******Script resuming, load Azure credentials in prompt******`n `n"
    Connect-AzureAD
    $PUGroup = Get-AzureADGroup -Filter "displayName eq '$name_pu'"
        if (!$PUGroup){
        Write-Output "`n The power users group is not present after 3+ hours, please investigate! Script Exiting"
        Exit-PSSession
        }
        Else {
            Write-Output "`n The power users group is present in Azure AD, checking/adding group role assignment..."
            $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $PUgroup.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
            If ($RoleStatus -ne "$app_name"){
                Write-Output "`n Adding `n Azure AD role assignment of $app_name for `n The power users group"
                New-AzureADGroupAppRoleAssignment -objectid $PUgroup.ObjectId -Principalid $PUgroup.Objectid -resourceid $sp.Objectid -id $appRole.id
            }
            Else {
            Write-Output "`n Azure AD role assignment of $app_name for `n The power users group is already present"
            }
        }
    }
    Else {
        Write-Output "`n The power users group is present in Azure AD, checking/adding group role assignment..."
        $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $PUgroup.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
        If ($RoleStatus -ne "$app_name"){
           Write-Output "`n Adding `n Azure AD role assignment of $app_name for `n The power users group"
           New-AzureADGroupAppRoleAssignment -objectid $PUgroup.ObjectId -Principalid $PUgroup.Objectid -resourceid $sp.Objectid -id $appRole.id
        }
        Else {
           Write-Output "`n Azure AD role assignment of $app_name for `n The power users group is already present"
        }
    }

    $BLGroup = Get-AzureADGroup -Filter "displayName eq '$name_bl'"
    if (!$BLGroup){
    Write-Output "`n The power users not present yet, sleeping another 1hr"
    Write-Output "`n `n******Expect Azure Credential screen when pause concludes*****`n `n"
    Start-Sleep -Seconds 3600
    Write-Output "`n `n*******Script resuming, load Azure credentials in prompt******`n `n"
    Connect-AzureAD
    $BLGroup = Get-AzureADGroup -Filter "displayName eq '$name_bl'"
        if (!$BLGroup){
        Write-Output "`n The power users group is not present after 3+ hours, please investigate! Script Exiting"
        Exit-PSSession
        }
        Else {
            Write-Output "`n The power users group is present in Azure AD, checking/adding group role assignment..."
            $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $BLgroup.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
            If ($RoleStatus -ne "$app_name"){
                Write-Output "`n Adding `n Azure AD role assignment of $app_name for `n The power users group"
                New-AzureADGroupAppRoleAssignment -objectid $BLgroup.ObjectId -Principalid $BLgroup.Objectid -resourceid $sp.Objectid -id $appRole.id
            }
            Else {
            Write-Output "`n Azure AD role assignment of $app_name for `n The billing group is already present"
            }
        }
    }
    Else {
        Write-Output "`n The power users group is present in Azure AD, checking/adding group role assignment..."
        $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $BLgroup.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
        If ($RoleStatus -ne "$app_name"){
           Write-Output "`n Adding `n Azure AD role assignment of $app_name for `n The power users group"
           New-AzureADGroupAppRoleAssignment -objectid $BLgroup.ObjectId -Principalid $BLgroup.Objectid -resourceid $sp.Objectid -id $appRole.id
        }
        Else {
           Write-Output "`n Azure AD role assignment of $app_name for `n The billing users group is already present"
        }
    }


$NameFormatted = $ROGroup.DisplayName + " and " + $PUGroup.DisplayName + " and " + $BLGroup.DisplayName
Write-Output "`n `n*******************CONGRATULATIONS*******************`n `n"
Write-Output "Groups $NameFormatted have been created/verified in ARS `n `n"
Write-Output "Groups have syned to Azure AD and have their roles assigned"
Write-Output "`n Wait up to 40 minutes for the sync to occur from Azure AD to AWS"