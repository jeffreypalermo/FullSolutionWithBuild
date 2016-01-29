[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False)][string]$serverNodeName = $env:computername,
    [Parameter(Mandatory=$False)][string]$ServerInstallPath = "C:\OctopusDeploy\Server",
    [Parameter(Mandatory=$False)][string]$ServerHomeDirectory = "C:\OctopusDeploy\Home\Server",
    [Parameter(Mandatory=$False)][string]$storageConnectionString = "Data Source=(local)\SQLEXPRESS;Initial Catalog=ClearMeasureBootcamp;Integrated Security=True", 
    [Parameter(Mandatory=$False)][string]$adminUser = "administrator",
    [Parameter(Mandatory=$False)][string]$adminPass = "Password@!",
    [Parameter(Mandatory=$False)][string]$serverUrl = "http://localhost:80/",
    [Parameter(Mandatory=$False)][string]$TentacleInstallPath = "C:\OctopusDeploy\Tentacle",
    [Parameter(Mandatory=$False)][string]$TentacleHomeDirectory = "C:\OctopusDeploy\Home\Tentacle",
    [Parameter(Mandatory=$False)][string]$LicenseFile = "od-license.xml"
)

function Test-IsLocalAdministrator {
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

$environments = @("Test", "Staging", "Production")
$roles = @("Web", "Service")
    
$toolsPath = "$PSScriptRoot\tools\octopus"

$OctopusServerMsi = "$toolsPath\octopus-server.msi"
$Server = $ServerInstallPath + "\Octopus.Server.exe"

$OctopusTentacleServerMsi = "$toolsPath\octopus-tentacle.msi"
$Tentacle = $TentacleInstallPath + "\Tentacle.exe"

$Octo = "$toolsPath\octo\Octo.exe";

Function DownloadTools{
    $starttime = Get-Date   
    Write-Banner "Downloading CI / CD Tools" $True
    
    #Create the tools directory
    New-Item $toolsPath -type directory -force | Out-Null
    
    $webclient = New-Object System.Net.WebClient;
    $urls = @{  "octopus-tentacle.msi" = "https://octopusdeploy.com/downloads/latest/OctopusTentacle64"
               ;"octopus-server.msi"   = "https://octopusdeploy.com/downloads/latest/OctopusServer64"
               ;"octo.zip"             = "https://octopusdeploy.com/downloads/latest/CommandLineTools"
               ;"Octopus.TeamCity.zip" = "https://octopusdeploy.com/downloads/latest/TeamCityPlugin"
             };
         
    # check the endpoints for a redirect and location header
    foreach($url in $urls.Clone().GetEnumerator()){
        
        $response = Invoke-WebRequest -Uri $url.Value -Method Head -MaximumRedirection 0 -ErrorAction Ignore
        
        if($response.StatusCode -eq 302){
            $urls[$url.Name] = $response.Headers.Location;
        }
        
        $remoteFileName = $url.Name
        $bareFileName = [System.IO.Path]::GetFileNameWithoutExtension($remoteFileName)
        $output = "$toolsPath\$remoteFileName";
        Write-Host -NoNewline " -" $url.Value
        $webclient.DownloadFile($url.Value, $output)
        Write-Host " $((Get-Date).Subtract($starttime).Seconds) second(s)" -foregroundcolor green

        # expand zip files into a extensionless filename directory
        if($remoteFileName.Contains(".zip")){
            # check powershell version, if 5+ use Expand-Archive
            $psVersion = $PSVersionTable.PSVersion.ToString().Substring(0,1)
            if ($psVersion -ge  5) 
            {
                Write-Host "   - expanding archive with Expand-Archive to $toolsPath\$bareFileName" 
                Expand-Archive -Force -Path $output -DestinationPath "$toolsPath\$bareFileName"
            } else {
                # if powershell version <5, use Expand-ArchivePreWin10
                Write-Host "   - expanding archive with Expand-ArchivePreWin10 to $toolsPath\$bareFileName" 
                Expand-ArchivePreWin10 -File $output -Destination "$toolsPath\$bareFileName"
            }

            Write-Host "   - removing $output"
            Remove-Item -Force -Path $output
        }
    }
}

Function InstallServer{
    
    Write-Banner "Installing Octopus Deploy server to $ServerInstallPath" $True
    $commandArgs = "/i $OctopusServerMsi /quiet INSTALLLOCATION=$ServerInstallPath /lv $toolsPath\Octopus-Server-Install-Log.txt"
    Start-Process "msiexec" $commandArgs -Wait -Verb RunAs
}

Function ConfigureServer{
    
    Write-Banner "Configuring Octopus Deploy server" $True

    $licenseFile = Get-Content $LicenseFile;
    $licenseFileBytes = [System.Text.Encoding]::UTF8.GetBytes($licenseFile);
    $licenseBase64 = [System.Convert]::ToBase64String($licenseFileBytes);
    
    $commands = @(
     "create-instance --instance `"OctopusServer`" --config `"$ServerHomeDirectory`\OctopusServer.config`""
    ,"configure --instance `"OctopusServer`" --home `"$ServerHomeDirectory`" --storageConnectionString `"$storageConnectionString`" --upgradeCheck `"True`"   --upgradeCheckWithStatistics `"True`" --webAuthenticationMode `"UsernamePassword`" --webForceSSL `"False`" --webListenPrefixes `"$serverUrl`"     --commsListenPort `"10943`" --serverNodeName `"$serverNodeName`""
    ,"database --instance `"OctopusServer`" --create --grant `"NT AUTHORITY\SYSTEM`""
    ,"service --instance `"OctopusServer`" --stop"
    ,"admin --instance `"OctopusServer`" --username `"$adminUser`" --password `"$adminPass`""
    ,"license --instance `"OctopusServer`" --licenseBase64 `"$licenseBase64`""
    ,"service --instance `"OctopusServer`" --install --reconfigure --start"
    );
    
    foreach($command in $commands){
        Write-Host $Server $command -ForegroundColor Green
        Start-Process -NoNewWindow -Wait -FilePath $Server -ArgumentList $command
    }
}

Function GetSeverThumbprint{
    $response = & $Server "show-thumbprint"
    return $response[2];
}

Function InstallTentacle{
    Write-Banner "Installing Octopus Deploy tentacle to $TentacleInstallPath" $True
    $commandArgs = "/i $OctopusTentacleServerMsi /quiet INSTALLLOCATION=$TentacleInstallPath /lv $toolsPath\Octopus-Tentacle-Install-Log.txt"
    Start-Process "msiexec" $commandArgs -Wait -Verb RunAs
}

Function ConfigureTentacle($thumbprint){
    Write-Banner "Configuring Octopus Deploy tentacle" $True

    $commands = @(
    "create-instance --instance `"Tentacle`" --config `"$TentacleHomeDirectory\Tentacle.config`""
    ,"new-certificate --instance `"Tentacle`" --if-blank"
    ,"configure --instance `"Tentacle`" --reset-trust"
    ,"configure --instance `"Tentacle`" --home `"$TentacleHomeDirectory`" --app `"$TentacleHomeDirectory\Applications`" --port `"10933`" --noListen `"False`""
    ,"configure --instance `"Tentacle`" --trust `"$thumbprint`""
#,"register-with --instance `"Tentacle`" --server="http://localhost" --apiKey="API-QEWDOJCW1GQQGOVXTOYMZBIIPQ" --env="Dev" --server-comms-port="10933" --role="web" --publicHostName=$env:computername --console
    );
    
    foreach($command in $commands){
        Write-Host $Tentacle $command -ForegroundColor Green
        Start-Process -NoNewWindow -Wait -FilePath $Tentacle -ArgumentList $command
    }
    
    Write-Host "Configuring the firewall" -ForegroundColor Yellow
    Start-Process -NoNewWindow -Wait -FilePath `"netsh`" -ArgumentList "advfirewall firewall add rule `"name=Octopus Deploy Tentacle`" dir=in action=allow  protocol=TCP localport=10933"
    
    Write-Host "Starting Tentacle" -ForegroundColor Green
    Start-Process -NoNewWindow -Wait -FilePath $Tentacle -ArgumentList "service --instance `"Tentacle`" --install --start"
}

Function CreateApiKey ($apiKeyName){
    
    #Adding libraries. Make sure to modify these paths acording to your environment setup.
    Add-Type -Path "$ServerInstallPath\Newtonsoft.Json.dll"
    Add-Type -Path "$ServerInstallPath\Octopus.Client.dll"
     
    #Creating a connection
    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $serverUrl
    $repository = new-object Octopus.Client.OctopusRepository $endpoint
    
    $LoginObj = New-Object Octopus.Client.Model.LoginCommand 
    
    #Login with credentials.
    $LoginObj.Username = $adminUser
    $LoginObj.Password = $adminPass
    
    $repository.Users.SignIn($LoginObj)
    
    $UserObj = $repository.Users.GetCurrent()
    
    $ApiObj = $repository.Users.CreateApiKey($UserObj, $apiKeyName)
    
    #Returns the API Key in clear text
    return $ApiObj.ApiKey    
}

Function CreateOctopusEnvironments($apiKey){

    Write-Banner "Creating Octopus Deploy Environments" $True
    
    foreach($environment in $environments){
        Write-Host " - $environment environment" -foregroundcolor green
        
        $command = "create-environment --server=$serverUrl --apiKey=$apiKey --name=`"$environment`""
        Start-Process -NoNewWindow -Wait -FilePath $Octo -ArgumentList $command
    }
}

Function CreateDeploymentTarget($apiKey){
    Write-Banner "Creating Octopus Deployment Targets" $True
    
    foreach($environment in $environments){
        foreach($role in $roles){
            $displayName = "$env:computername-$environment-$role"
            Write-Host " Creating deployment target $role in $environment" -foregroundcolor green 
            $command = "register-with --instance `"Tentacle`" --server=`"http://localhost`" --apiKey=`"$apiKey`" --env=`"$environment`" --server-comms-port=`"10933`" --role=`"$role`" --name=`"$displayName`" --publicHostName=`"$env:computername`" --console --nologo";
            Start-Process -NoNewWindow -Wait -FilePath $Tentacle -ArgumentList $command
        }
    }    
}

Function Write-Banner{
Param(
    [Parameter(Mandatory=$True)][string]$message,
    [Parameter(Mandatory=$False)][string]$banner = $false,
    [Parameter(Mandatory=$False)][string]$color = "green"
)
    
    $header = "--------------------------------------------------------------------";
    if($banner -eq $True){
        Write-Host $header -foregroundcolor $color
    }
    
    Write-Host "$message" -foregroundcolor $color
    
    if($banner -eq $True){
        Write-Host $header -foregroundcolor $color
    }
}

function Expand-ArchivePreWin10($file, $destination)
{
    $shell = new-object -com shell.application
    $zip = $shell.NameSpace($file)
    
    foreach($item in $zip.items())
    {
        $shell.Namespace($destination).copyhere($item, 0x10)
    }
}

# ** ** ** ** ** ** ** ** ** 
#  Procedural Execution
# ** ** ** ** ** ** ** ** ** 
if(-Not (Test-IsLocalAdministrator) -eq $True){
    Write-Banner -Message "Not Local Admin: Please run Powershell as Administrator" -color red
    exit;
}

DownloadTools;
InstallServer;
ConfigureServer;
$thumbprint = GetSeverThumbprint;
InstallTentacle;
ConfigureTentacle($thumbprint);
$apiKey = CreateApiKey("Clear-Measure-Bootcamp-"+(Get-Date).Ticks);
Write-Banner "Created API Key: $apiKey" -banner $true -color Green
CreateOctopusEnvironments($apiKey);
CreateDeploymentTarget($apiKey);