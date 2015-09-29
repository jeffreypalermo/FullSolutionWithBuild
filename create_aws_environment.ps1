$env:path += ";C:\Program Files\Amazon\AWSCLI\"

# function Create-Stack
# {
# 	aws cloudformation create-stack --stackname ClearMeasureBootcamp --template-body file:///src/AWS/BootCamp.template --parameters file:///src/AWS/cf_parameters.json
# }
# 
# function Get-Stack-Creation-Status
# {
# 	aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE #get status of CF stack
# }
# 
# Create-Stack

# $stack = aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE
# 
# while($stack -ne "CREATE_COMPLETE")
# {
#   Start-Sleep -s 60
#   Write-Host "Still creating stack"
# }

$initial_state = aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE
aws cloudformation create-stack --stackname ClearMeasureBootcamp --template-body file:///src/AWS/BootCamp.template --parameters file:///src/AWS/cf_parameters.json

do {
  $stack = aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE
  Start-Sleep -s 60
  Write-Host "Still creating stack"
} while ($stack -eq $initial_state)