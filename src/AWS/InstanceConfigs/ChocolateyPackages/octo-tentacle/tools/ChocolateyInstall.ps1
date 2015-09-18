try {

# example: cinst ls-octo-tentacle -y -packageParameters "/AdminPassword:Password" -source C:\InstallPackages
Update-SessionEnvironment
cinst octopustools

$arguments = @{}

  # Let's assume that the input string is something like this, and we will use a Regular Expression to parse the values
  # example: cinst web-server-role -packageParameters "/AdminUser:User /AdminPassword:Password " -y -source c:\InstallPackages

  # Now we can use the $env:chocolateyPackageParameters inside the Chocolatey package
  $packageParameters = $env:chocolateyPackageParameters

  # Default the values
  $adminPasword = ""
  $adminUser = ""

  # Now parse the packageParameters using good old regular expression
  if ($packageParameters) {
      $match_pattern = "\/(?<option>([a-zA-Z_]+)):(?<value>((?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{8,15}$))"
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

# If for whatever reason this doesn't work, check this file:
mkdir "C:\InstallLogs" -ErrorAction SilentlyContinue
Start-Transcript -path "C:\InstallLogs\TentacleInstallLog.txt" -append

$tentacleDownloadPath = "https://download.octopusdeploy.com/octopus/Octopus.Tentacle.2.6.5.1010-x64.msi"
$yourApiKey = $env:OCTOSERVER_APIKEY
$octopusServerUrl = "http://build.clear-measure.com:7070/"
$registerInEnvironments = $env:OCTOSERVER_ENV
$registerInRoles = $env:OCTOSERVER_ROLE
$octopusServerThumbprint = $env:OCTOSERVER_THUMBPRINT
$softwareVersion = $env:OCTOSERVER_VERSION
$OctopusProject = $env:OCTOSERVER_PROJECT
$tentacleListenPort = 10933
$tentacleHomeDirectory = "$env:SystemDrive:\Octopus"
$tentacleAppDirectory = "$env:SystemDrive:\Octopus\Applications"
$tentacleConfigFile = "$env:SystemDrive\Octopus\Tentacle\Tentacle.config"

function Download-File
{
  param (
    [string]$url,
    [string]$saveAs
  )

  Write-Host "Downloading $url to $saveAs"
  $downloader = new-object System.Net.WebClient
  $downloader.DownloadFile($url, $saveAs)
}

# We're going to use Tentacle in Listening mode, so we need to tell Octopus what its IP address is. Since my Octopus server
# is hosted somewhere else, I need to know the public-facing IP address.
function Get-MyPublicIPAddress
{
  Write-Host "Getting public IP address"
  $downloader = new-object System.Net.WebClient
  $ip = $downloader.DownloadString("http://checkip.dyndns.com") -replace "[^\d\.]"
  return $ip
}

function Install-Tentacle
{
  param (
     [Parameter(Mandatory=$True)]
     [string]$apiKey,
     [Parameter(Mandatory=$True)]
     [System.Uri]$octopusServerUrl,
     [Parameter(Mandatory=$True)]
     [string]$environment,
     [Parameter(Mandatory=$True)]
     [string]$role
  )

  $ipAddress = Get-MyPublicIPAddress
  $ipAddress = $ipAddress.Trim()

  Write-Output "Public IP address: " + $ipAddress

  Write-Output "Beginning Tentacle installation"

  Write-Output "Downloading latest Octopus Tentacle MSI..."

  $tentaclePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Tentacle.msi")
  if ((test-path $tentaclePath) -ne $true) {
    Download-File $tentacleDownloadPath $tentaclePath
  }

  Write-Output "Installing MSI"
  $msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i Tentacle.msi /quiet" -Wait -Passthru).ExitCode
  Write-Output "Tentacle MSI installer returned exit code $msiExitCode"
  if ($msiExitCode -ne 0) {
    throw "Installation aborted"
  }

  Write-Output "Open port $tentacleListenPort on Windows Firewall"
  & netsh.exe firewall add portopening TCP $tentacleListenPort "Octopus Tentacle"
  if ($lastExitCode -ne 0) {
    throw "Installation failed when modifying firewall rules"
  }

  Write-Output "Configuring and registering Tentacle"

  cd "${env:ProgramFiles}\Octopus Deploy\Tentacle"

  & .\tentacle.exe create-instance --instance "Tentacle" --config $tentacleConfigFile --console | Write-Host
  if ($lastExitCode -ne 0) {
    throw "Installation failed on create-instance"
  }
  & .\tentacle.exe configure --instance "Tentacle" --home $tentacleHomeDirectory --console | Write-Host
  if ($lastExitCode -ne 0) {
    throw "Installation failed on configure"
  }
  & .\tentacle.exe configure --instance "Tentacle" --app $tentacleAppDirectory --console | Write-Host
  if ($lastExitCode -ne 0) {
    throw "Installation failed on configure"
  }
  & .\tentacle.exe configure --instance "Tentacle" --port $tentacleListenPort --console | Write-Host
  if ($lastExitCode -ne 0) {
    throw "Installation failed on configure"
  }
  & .\tentacle.exe new-certificate --instance "Tentacle" --console | Write-Host
  if ($lastExitCode -ne 0) {
    throw "Installation failed on creating new certificate"
  }
  & .\tentacle.exe configure --instance "Tentacle" --trust $octopusServerThumbprint --console  | Write-Host
  if ($lastExitCode -ne 0) {
    throw "Installation failed on configure"
  }

  & .\tentacle.exe service --instance "Tentacle" --install --start --console | Write-Host
  if ($lastExitCode -ne 0) {
    throw "Installation failed on service install"
  }

  Write-Output "Tentacle commands complete"
}

$yourApiKey = $env:OCTOSERVER_APIKEY
$octopusServerUrl = $env:OCTOSERVER_URL
$registerInEnvironments = $env:OCTOSERVER_ENV
$registerInRoles = $env:OCTOSERVER_ROLE
$octopusServerThumbprint = $env:OCTOSERVER_THUMBPRINT
$softwareVersion = $env:OCTOSERVER_VERSION
$OctopusProject = $env:OCTOSERVER_PROJECT

$RegisterScript = @"
# If for whatever reason this doesn't work, check this file:
Start-Transcript -path "C:\InstallLogs\TentacleRegistrationLog.txt" -append

`$yourApiKey = "`$env:OCTOSERVER_APIKEY"
`$octopusServerUrl = "`$env:OCTOSERVER_URL"
`$octopusThumbprint = "`$env:OCTOSERVER_THUMBPRINT"
`$octopusenvironment = "`$env:OCTOSERVER_ENV"
`$octopusServerRole = "`$env:OCTOSERVER_ROLE"


function Get-MyPublicIPAddress
{
  Write-Host "Getting public IP address"
  `$downloader = new-object System.Net.WebClient
  `$ip = `$downloader.DownloadString("http://checkip.dyndns.com") -replace "[^\d\.]"
  return `$ip
}

function Register-Tentacle
{
    param (
        [Parameter(Mandatory=`$True)]
        [string]`$apiKey,
        [Parameter(Mandatory=`$True)]
        [System.Uri]`$octopusServerUrl,
        [Parameter(Mandatory=`$True)]
        [string]`$octopusServerThumbprint,
        [Parameter(Mandatory=`$True)]
        [string]`$environment,
        [Parameter(Mandatory=`$True)]
        [string]`$role
    )

    `$softwareVersion = "`$env:OCTOSERVER_VERSION"
    `$OctopusProject = "`$env:OCTOSERVER_PROJECT"
    Write-Host "Stop Octopus Tentacle Service..."
    Stop-Service "OctopusDeploy Tentacle" -Verbose

    # give the service 2 seconds to spin up
    Start-Sleep 2

    Write-Host "Beginning Tentacle Registration"

    cd "`${env:ProgramFiles}\Octopus Deploy\Tentacle"

    & .\tentacle.exe register-with --instance "Tentacle" --server `$octopusServerUrl --environment `$environment --role `$role --name `$env:COMPUTERNAME --publicHostName `$ipAddress --apiKey `$apiKey --comms-style TentaclePassive --force --console | Write-Host
    if (`$lastExitCode -ne 0) {
    throw "Installation failed on register-with"
    }

    Write-Host "Restart Octopus Tentacle Service..."
    Start-Service "OctopusDeploy Tentacle" -Verbose

    Write-Host "Tentacle Registration complete"

    `$nameChanged = (Get-WmiObject -query "SELECT * FROM Win32_NTLogEvent WHERE (logfile='System') AND (eventcode='6011')" | `
      where {`$_.TimeGenerated -gt (`$_.ConvertFromDateTime((Get-Date).AddMinutes(-15)))} | `
      Select-Object -First 1) -ne `$null

      if (`$nameChanged)
      {
        # install the passed in version of the software for the role passed in
        octo deploy-release --project `$OctopusProject --releaseNumber `$softwareVersion --deployto `$environment --server `$octopusServerUrl --specificmachines `$env:COMPUTERNAME --apiKey `$apiKey
      }

}

`$ipAddress = Get-MyPublicIPAddress
`$ipAddress = `$ipAddress.Trim()

Register-Tentacle -apikey `$yourApiKey -octopusServerUrl `$octopusServerUrl -octopusServerThumbprint `$octopusThumbprint -environment `$octopusenvironment -role `$octopusServerRole
"@

# create the startup and shutdown scripts
if(!(Test-Path "C:\Scripts\Shutdown"))
{
    mkdir -ErrorAction SilentlyContinue "C:\Scripts\Shutdown"
}
$DeregisterScript | Out-File "C:\Scripts\Shutdown\DeregisterOctoTentacle.ps1"

if(!(Test-Path "C:\Scripts\Startup"))
{
    mkdir -ErrorAction SilentlyContinue "C:\Scripts\Startup"
}
$RegisterScript | Out-File "C:\Scripts\Startup\RegisterOctoTentacle.ps1"

Write-Output "Check if Environment Variables have been initialized"
$isEnvVariableInitComplete = ((Test-Path env:OCTOSERVER_APIKEY) -and (Test-Path env:OCTOSERVER_URL) -and (Test-Path env:OCTOSERVER_ENV) `
   -and (Test-Path env:OCTOSERVER_ROLE) -and (Test-Path env:OCTOSERVER_THUMBPRINT) -and (Test-Path env:OCTOSERVER_VERSION) -and (Test-Path env:OCTOSERVER_PROJECT))

Write-Output "Checking if Tentacle is installed"
$isInstalled = (get-itemproperty -path "HKLM:\Software\Octopus\Tentacle" -ErrorAction SilentlyContinue) -ne $null

Write-Output "Tentacle previously installed: $isInstalled"
Write-Output "Environment Variables Initialized: $isEnvVariableInitComplete"
if ($isEnvVariableInitComplete)
{
  Install-Tentacle -apikey $yourApiKey -octopusServerUrl $octopusServerUrl -environment $registerInEnvironments -role $registerInRoles

  # configure the shutdown script to run
  $toolsDirectory = "$(split-path -parent $MyInvocation.MyCommand.Definition)"
  Write-Output "Importing registry settings from: $toolsDirectory\DeregisterOctoTentacle.reg"

  $user = $adminUser
  $password = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
  $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

  reg import $toolsDirectory\DeregisterOctoTentacle.reg
  $startTrigger = New-JobTrigger -AtStartup -RandomDelay 00:00:30
  Write-Output "Scheduling Registration at startup..."
  Register-ScheduledJob -Trigger $startTrigger -FilePath "C:\Scripts\Startup\RegisterOctoTentacle.ps1" -Name RegisterOctpusTentacle -Credential $cred
  Get-Job
}
else
{
    $errorMessage = ""
    if($isInstalled)
    {
      $errorMessage = "Tentacle has previously been installed"
    }
    if(!($isEnvVariableInitComplete))
    {
      $errorMessage = "Octopus Specific Environment Variables have not been initialized"
    }
    throw $errorMessage
}
} catch {
  throw $_.Exception.Message
}
