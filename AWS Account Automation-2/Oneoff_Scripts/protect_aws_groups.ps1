# finds AWS groups and sets them to protected from accidental deletion
# Ryan Greer - 3/2/2021

$awsgroups = Get-ADGroup -Filter {Name -like 'BSAM_AWS_*'}

ForEach ($awsgroup in $awsgroups){
get-adobject $awsgroup -properties * | where {$_.ProtectedFromAccidentalDeletion -eq $false} | Set-ADObject -ProtectedFromAccidentalDeletion $True
}
 
