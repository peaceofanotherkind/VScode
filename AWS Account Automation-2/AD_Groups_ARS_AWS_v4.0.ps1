#Script written in tandem by Ryan Greer and Jerad Johnson @ ICE 4.2021
#Script is to create groups if not present and update with members if present
#Script uses user input for groups and members
####################################################################################
#Setting static variables
####################################################################################
$SMTPServer = "mailedge.bfusa.com"
$From = "donotreply@bfusa.com"
$AADCredsNotification = "Time to enter creds into AAD logon prompt" 
$ErrorNotification = "The script errored due to AAD Sync issue - Verify ARS has group/members and check w/ AAD Sync" 
$CompletionNotification = "Script completed - Continue with AWS efforts in 40 minutes"
$AWS45Notification = "Check AWS to finish account tasks"
$ou = "bfusa.com/AdminDomain/Groups/Privileged Groups"
$type = "Security"
$scope = "Global"
$managedby = "BSA-IT-ICE-Admins"
$description = "AWS access group"
$app_name = "SSO_BSAM_AWS"
$app_role_name = "User"
####################################################################################
Write-Output "`n This script conducts the following: `n - The creation of an AD group that doesnt exist and updates to existing AD groups `n - Adds users to existing/new groups `n - Syns groups to AAD `n - Marks to be used in AWS SSO"
Import-Module ActiveRolesManagementShell
Write-Host "`n Please sign in using your a-account.  This is for ARS connectivity `n"
$qadcred = get-credential
Connect-QADService -proxy -credential $qadcred
$EmailAddress = (Read-Host "Please enter your email address for notifications")
$To = @($EmailAddress)
Write-Output "`n When creating groups, paste the name of the corresponding AWS Permissions Set, enter each (one-per-line) in the following format AcmeCorp-Billing-SpecialReports"
Write-Output "`n In this example, pasting in the AWS Permission Set name: AcmeCorp-Billing-SpecialReports will create the following AD group: BSAM_AWS_AcmeCorp_Billing_SpecialReports"
Write-Output "`n When entering usernames, enter each (one-per-line) in the following UPN format (example: user1@bfusa.com)"
Write-Output "`n To stop entering groups and users, just leave next line empty and hit enter"
Write-Output "`n Please enter names of groups"
$ADGroupPrefix = "BSAM_AWS_"
$Groups = @()
    do {
    $input = (Read-Host "PASTE the *AWS Permission Set* name here and script will create the corresponding AD group:")
    if ($input -like '_*'){
            Write-Output "This is a baseline permission set as it starts with an _underscore"
            $AccountNameInput = Read-Host -Prompt "Please PASTE the AWS Account Name here (example: AcmeCorp):"
            $ADGroupNameConverted = $ADGroupPrefix + $AccountNameInput + $input
            $Groups += $ADGroupNameConverted
            }
    elseif ($input -ne '') {
        if ($input.Length -gt '32'){
            Write-Output "*****Improper Paste of AWS Permission Set Name as value exceeds 32char AWS hard limit******`n `n"
            Read-Host -Prompt "Press any key to exit the script"
            exit
            }
        else {}
        $PermSetArray = $input.Split("-")
        if ($PermSetArray.Count -eq 2){
            $ADGroupNameConverted = $ADGroupPrefix + $PermSetArray[0] + "_" + $PermSetArray[1]
            $Groups += $ADGroupNameConverted
            }
        elseif ($PermSetArray.Count -eq 3){
            $ADGroupNameConverted = $ADGroupPrefix + $PermSetArray[0] + "_" + $PermSetArray[1] + "_" + $PermSetArray[2]
            $Groups += $ADGroupNameConverted
            }
        elseif ($PermSetArray.Count -eq 4){
            $ADGroupNameConverted = $ADGroupPrefix + $PermSetArray[0] + "_" + $PermSetArray[1] + "_" + $PermSetArray[2] + "_" + $PermSetArray[3]
            $Groups += $ADGroupNameConverted
            }
        else {
            Write-Output "*****Permission set fell outside the naming standards******`n `n"
            Read-Host -Prompt "Press any key to exit the script"
            exit
            }
        }
    }
    until (!$input)
$GroupString = "'$($Groups -join "','")'"
Write-Output "The following group(s) will be created and/or updated: $GroupString"
foreach ($Group in $Groups){
    $GroupPresent = Get-qADGroup -Name $Group | select Name -ExpandProperty Name
    If (!$GroupPresent){
        Write-Output "$Group not present, creating..."
        New-qADGroup -ParentContainer $ou -Name $Group -DisplayName $Group -Description $description -GroupScope $scope -GroupType $type -ManagedBy $managedby -ManagerCanUpdateMembershipList $true
        Set-qADGroup $Group -objectattributes @{extensionAttribute12="BSAM"}
        Set-qADObject $Group -objectattributes @{edsvaProtectFromDeletion=$True}
        Set-qADGroup $Group -objectattributes @{bsam_isnomerge="True"}
    }
    Else {}
    $Users = @()
    do {
    $input = (Read-Host "`n Enter username for group: $Group")
    if ($input -ne '') {$Users += $input}
    }
    #until ($input -eq 'end')
    until (!$input)
    #$Users = $Users | Where-Object { $_ -ne "end" }
    $UserList = "'$($Users -join "','")'"
    Write-Output "`n The following users will be added to group: $Group :: $UserList"
    foreach ($User in $Users){
        Add-QADGroupMember $Group $User
    }
 }
####################################################################################
Write-Output "`n `n*******************IMPORTANT - PLEASE READ!*******************`n `n"
Write-Output "*****Group creation and existence verification completed******`n `n"
Write-Output "***Script pausing 1h for sync - DO NOT CLOSE THIS WINDOW!!!***`n `n"
Write-Output "******Expect Azure Credential screen when pause concludes*****`n `n"
Get-Date -Format "dddd MM/dd/yyyy HH:mm"
Start-Sleep -Seconds 3600
################################################################################
################################################################################
Write-Output "`n `n *******Script resuming, Installing Azure AD Module******`n `n"
Install-Module AzureAD -force
Send-MailMessage -To $To -Subject "ATTENTION - AAD Creds Needed!" -Body $AADCredsNotification -SmtpServer $SMTPServer -From $From
Write-Output "`n `n ***********Input Azure credentials in prompt************`n `n"
Connect-AzureAD
$sp = Get-AzureADServicePrincipal -Filter "displayName eq '$app_name'"
$appRole = $sp.AppRoles | Where-Object { $_.DisplayName -eq $app_role_name }
foreach ($Group in $Groups){
    $AADGroup = Get-AzureADGroup -Filter "displayName eq '$Group'"
    $AADGroupName = $AADGroup.DisplayName
    if (!$AADGroup){
    Write-Output "The group: $Group not present in Azure AD yet, sleeping another 1hr"
    Write-Output "`n `n******Expect Azure Credential screen when pause concludes*****`n `n"
    Start-Sleep -Seconds 3600
    Send-MailMessage -To $To -Subject "ATTENTION - Azure AD Creds Needed, AGAIN!" -Body $AADCredsNotification -SmtpServer $SMTPServer -From $From
    Write-Output "`n `n*******Script resuming, load Azure credentials in prompt******`n `n"
    Connect-AzureAD
    $AADGroup = Get-AzureADGroup -Filter "displayName eq '$Group'"
        if (!$AADGroup){
        Write-Output "The group: $Group is not present in Azure AD after 2 hours, please investigate! Script Exiting"
        Exit-PSSession
            }
        Else {
            Write-Output "`n The group: $AADGroupName is present in Azure AD, checking/adding group role assignment..."
            $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $AADGroup.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
            If ($RoleStatus -ne "$app_name"){
                Write-Output "`n Adding Azure AD role assignment of $app_name for the group: $AADGroupName"
                New-AzureADGroupAppRoleAssignment -objectid $AADGroup.ObjectId -Principalid $AADGroup.Objectid -resourceid $sp.Objectid -id $appRole.id
                }
            Else {
            Write-Output "`n Azure AD role assignment of $app_name for the group: $AADGroupName is already present"
                }
        }
    }
    Else {
        Write-Output "`n The group: $AADGroupName is present in Azure AD, checking/adding group role assignment..."
        $RoleStatus = Get-AzureADGroupAppRoleAssignment -objectid $AADGroup.ObjectId | select ResourceDisplayName -ExpandProperty ResourceDisplayName
        If ($RoleStatus -ne "$app_name"){
           Write-Output "`n Adding Azure AD role assignment of $app_name for the group: $AADGroupName"
           New-AzureADGroupAppRoleAssignment -objectid $AADGroup.ObjectId -Principalid $AADGroup.Objectid -resourceid $sp.Objectid -id $appRole.id
        }
        Else {
           Write-Output "`n Azure AD role assignment of $app_name for the group: $AADGroupName is already present"
        }
    }
    }
Write-Output "`n `n*******************CONGRATULATIONS*******************`n `n"
Write-Output "Group(s) $GroupString is/are created/verified in ARS `n `n"
Write-Output "Group(s) $GroupString is/are syned to Azure AD and have the app role assigned"
Write-Output "`n Please wait up to 40 minutes for the sync to occur from Azure AD to AWS"
Send-MailMessage -To $To -Subject "SUCCESS - script completed, wait 40m for AWS" -Body $CompletionNotification -SmtpServer $SMTPServer -From $From
Write-Output "`n Sleeping 45 minutes and then emailing a reminder (If you dont close this!)"
Start-Sleep -Seconds 2700
Send-MailMessage -To $To -Subject "Check AWS to finish account tasks" -Body $AWS45Notification -SmtpServer $SMTPServer -From $From