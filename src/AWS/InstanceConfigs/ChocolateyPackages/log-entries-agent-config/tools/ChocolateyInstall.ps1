$arguments = @{}

  # Let's assume that the input string is something like this, and we will use a Regular Expression to parse the values
  # -packageParameters "/ACCOUNT_KEY:$logEntriesAccountKey /GROUP_NAME:$logEntriesGroupName" -y -source 'C:\InstallPackages'

  # Now we can use the $env:chocolateyPackageParameters inside the Chocolatey package
  $packageParameters = $env:chocolateyPackageParameters
  $installLogs = "$env:SystemDrive\InstallLogs"

  # Default the values
  $accountKey = "0"
  $groupName = $env:COMPUTERNAME
  if(test-path ENV:OCTOSERVER_ENV)
  {
    $groupName = "$env:OCTOSERVER_ENV-$env:COMPUTERNAME"
  }

  # Now parse the packageParameters using good old regular expression
  if ($packageParameters) {
      $match_pattern = "\/(?<option>([a-zA-Z_]+)):(?<value>([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}))|\/(?<option>([a-zA-Z_]+)):(?<value>([a-zA-Z0-9_]+))"
      $option_name = 'option'
      $value_name = 'value'

      if ($packageParameters -match $match_pattern ){
          $results = $packageParameters | Select-String $match_pattern -AllMatches
          $results.matches | % {
            $arguments.Add(
                $_.Groups[$option_name].Value.Trim(),
                $_.Groups[$value_name].Value.Trim())
        }
      }
      else
      {
          Throw "Package Parameters were found but were invalid (REGEX Failure)"
      }

      if ($arguments.ContainsKey("ACCOUNT_KEY")) {
          Write-Host "License Key Argument Found"
          $accountKey = $arguments["ACCOUNT_KEY"]
      }

      if ($arguments.ContainsKey("GROUP_NAME")) {
          Write-Host "Group Name Argument Found"
          $groupName = $arguments["GROUP_NAME"]
      }

  } else {
      Write-Debug "No Package Parameters Passed in"
  }

  mkdir $installLogs -ErrorAction SilentlyContinue
  $silentArgs = "/quiet /log $installLogs\LogEntriesinstallLog.txt ACCOUNT_KEY=$accountKey GROUP_NAME=`"$($groupName)`""
  Write-Host $silentArgs
  $installPath = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
  Install-ChocolateyZipPackage 'LogEntriesInstaller' 'http://rep.logentries.com/windows/Windows-Agent.zip' $installPath

  Install-ChocolateyInstallPackage 'LogEntriesAgent' 'msi' $silentArgs "$installPath\Windows-Agent\AgentSetup.msi"
