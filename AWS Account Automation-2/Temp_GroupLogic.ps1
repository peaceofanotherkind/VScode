###all to get added into script (not in right order)

$SMTPServer = "mailedge.bfusa.com"
$From = "donotreply@bfusa.com"
$EmailAddress = (Read-Host "please enter your email address for notifications")
$To = @($EmailAddress)
$AADCredsNotification = "Time to enter creds into AAD logon prompt" 
$ErrorNotification = "The script errored due to AAD Sync issue - Verify ARS has group/members and check w/ AAD Sync" 
$CompletionNotification = "Script completed - Continue with AWS efforts in 40 minutes"
    Send-MailMessage -To $To -Subject "ATTENTION - AAD Creds Needed!" -Body $AADCredsNotification -SmtpServer $SMTPServer -From $From
    Send-MailMessage -To $To -Subject "ATTENTION - Script errored - action needed!" -Body $ErrorNotification -SmtpServer $SMTPServer -From $From
    Send-MailMessage -To $To -Subject "SUCCESS - script completed, wait 40m for AWS" -Body $CompletionNotification -SmtpServer $SMTPServer -From $From
$Groups = @()
    do {
    $input = (Read-Host "Please enter name of group")
    if ($input -ne '') {$Groups += $input}
    }
    #Complete loop with use of the word "end"
    until ($input -eq 'end')

$Groups = $Groups | Where-Object { $_ -ne "end" }
$GroupString = "'$($Groups -join "','")'"
Write-Output "The following groups will be created and/or updated: $GroupString"

foreach ($Group in $Groups){
    $Users = @()
    do {
    $input = (Read-Host "Please enter username to add to $Group")
    if ($input -ne '') {$Users += $input}
    }
    #Complete loop with use of the word "end"
    until ($input -eq 'end')
    $Users = $Users | Where-Object { $_ -ne "end" }
    $UserList = "'$($Users -join "','")'"
    Write-Output "The following users will be added to group: $Group :: $UserList"
    foreach ($User in $Users){
        Write-Output "DO THE THINGS - The user: $user is in group: $Group"
    }
 }

