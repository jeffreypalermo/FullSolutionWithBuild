Import-Module carbon

$arguments = @{}

  # Let's assume that the input string is something like this, and we will use a Regular Expression to parse the values
  # example: cinst web-server-role -packageParameters "/AdminUser:$adminUser /AdminPassword:$adminPassword" -y -source 'C:\InstallPackages'

  # Now we can use the $env:chocolateyPackageParameters inside the Chocolatey package
  $packageParameters = $env:chocolateyPackageParameters
  $installPackagesPath = $env:"$env:SystemDrive\InstallPackages"

  # Default the values
  $adminPasword = ""
  $adminUser = ""
  $logEntriesGroupName = $env:LOGENTRIES_GROUP
  $logEntriesAccountKey = $env:LOGENTRIES_KEY
  $newRelicLicenseKey = $env:NEWRELIC_KEY
  $newRelicEnvironments = "PROD","PERF"

  # Now parse the packageParameters using good old regular expression
  if ($packageParameters) {
      $match_pattern = "\/(?<option>([a-zA-Z_]+)):(?<value>([a-zA-Z0-9][a-zA-Z0-9-_.]{2,16}[a-zA-Z0-9]))(?= /)+|\/(?<option>([a-zA-Z_]+)):(?<value>((?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{8,15}$))"
      $option_name = 'option'
      $value_name = 'value'

      if ($packageParameters -match $match_pattern ){
          $results = $packageParameters | Select-String $match_pattern -AllMatches
          $results.matches | ForEach-Object {
            $arguments.Add(
                $_.Groups[$option_name].Value.Trim(),
                $_.Groups[$value_name].Value.Trim())
        }
      }
      else
      {
          Throw "Password must be at least 8 characters, no more than 15 characters, and must include at least one upper case letter, one lower case letter, and one numeric digit."
      }

      if ($arguments.ContainsKey("AdminPassword")) {
          Write-Host "Admin Password Found"
          $adminPassword = $arguments["AdminPassword"]
      }
      if ($arguments.ContainsKey("AdminUser")) {
          Write-Host "Admin User Found"
          $adminUser = $arguments["AdminUser"]
      }
  } else {
      Write-Debug "No Package Parameters Passed in"
  }

Write-Output "Renaming Computer to match Environment Type"
$environment = $env:ENVIRONMENT_TYPE
$newName = $environment + '-' + ([system.guid]::NewGuid().ToString()).Substring(30)
Rename-Computer -NewName $newName

# change the default Password
Write-Host "Adding local admin user for maintenance"
Install-User -Username $adminUser -Description "LocalAdmin" -FullName "Local Admin maintenance" -Password $adminPassword
Add-GroupMember -Name 'Administrators' -Member $adminUser

cinst web-server-config -y -source $installPackagesPath
cinst octo-tentacle -y -packageParameters "/AdminUser:$adminUser /AdminPassword:$adminPassword" -source $installPackagesPath
<# cinst ls-log-entries-agent-config -packageParameters "/ACCOUNT_KEY:$logEntriesAccountKey /GROUP_NAME:$logEntriesGroupName" -y -source $installPackagesPath
if($newRelicEnvironments.Contains($env:ENVIRONMENT_TYPE))
{
  cinst new-relic-agent -packageParameters "/NR_LICENSE_KEY:$newRelicLicenseKey" -y -source $installPackagesPath
  cinst new-relic-server-monitor -packageParameters "/NR_LICENSE_KEY:$newRelicLicenseKey" -y -source $installPackagesPath
}
#>
# get creds to restart the computer
Restart-Computer -Computer $env:COMPUTERNAME -Force
