$env:path += ";C:\Program Files\Amazon\AWSCLI\"
$stack_name = "ClearMeasureBootcamp"
$creation_complete = "CREATE_COMPLETE"
$creation_failed = "CREATE_FAILED"
$rollback_complete = "ROLLBACK_COMPLETE"
$rollback_in_progress = "ROLLBACK_IN_PROGRESS"
$creation_in_progress = "CREATE_IN_PROGRESS"
$aws_region = "us-east-1"
$template_body_url = 'https://s3.amazonaws.com/cm-projectbootcamp/cloud_formation/BootCamp.template'
$parameters_url = 'https://s3.amazonaws.com/cm-projectbootcamp/cloud_formation/cf_parameters.json'

function CreateStack {
  aws cloudformation create-stack --region $aws_region --stack-name $stack_name --template-body $template_body_url --parameters $parameters_url
}

function DeleteStack {
  aws cloudformation delete-stack --stack-name $stack_name
}

CreateStack 
 
 do {
  $all_stacks = aws cloudformation list-stacks | ConvertFrom-JSON
  
  $bootcamp_stack = $all_stacks.StackSummaries | ? { $_.StackName -eq $stack_name } | Select -First 1
    
  $current_status = $bootcamp_stack.StackStatus
  Write-Host $current_status
  
  If ($current_status -eq $creation_complete) { break }
  
  If ($current_status -eq $rollback_complete) {  
    DeleteStack
	CreateStack
  }
  Else {
	Start-Sleep -s 60
    Write-Host "Still creating stack"
  }
} while ( $current_status -eq $creation_in_progress -Or $current_status -eq $creation_failed -Or $current_status -eq $rollback_in_progress )
