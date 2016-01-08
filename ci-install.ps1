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

$toolsPath = "$PSScriptRoot\tools\octopus"

$OctopusServerMsi = "$toolsPath\octopus-server.msi"
$Server = $ServerInstallPath + "\Octopus.Server.exe"

$OctopusTentacleServerMsi = "$toolsPath\octopus-tentacle.msi"
$Tentacle = $TentacleInstallPath + "\Tentacle.exe"

$Octo = "$toolsPath\octo\Octo.exe";

Function DownloadTools{
    
    $webclient = New-Object System.Net.WebClient;
    $urls = @{  "octopus-tentacle.msi" = "https://octopus.com/downloads/latest/OctopusTentacle64"
               ;"octopus-server.msi"   = "https://octopus.com/downloads/latest/OctopusServer64"
               ;"octo.zip"             = "https://octopusdeploy.com/downloads/latest/CommandLineTools"
               ;"Octopus.TeamCity.zip" = "https://octopusdeploy.com/downloads/latest/TeamCityPlugin"
             };
         
    # check the endpoints for a redirect and location header
    foreach($url in $urls.Clone().GetEnumerator()){
        
        $response = Invoke-WebRequest -Uri $url.Value -Method Head -MaximumRedirection 0 -ErrorAction Ignore
        
        if($response.StatusCode -eq 302){
            $urls[$url.Name] = $response.Headers.Location;
        }
    }
        
    #Create the tools directory
    New-Item $toolsPath -type directory -force | Out-Null
    
    Write-Output "Starting download of:"
    $starttime = Get-Date
    foreach($url in $urls.GetEnumerator()) {
        $remoteFileName = $url.Name
        $bareFileName = [System.IO.Path]::GetFileNameWithoutExtension($remoteFileName)
        $output = "$toolsPath\$remoteFileName";
        Write-Host -NoNewline " -" $url.Value
        $webclient.DownloadFile($url.Value, $output)
        Write-Host " $((Get-Date).Subtract($starttime).Seconds) second(s)" -foregroundcolor green
            
        # expand zip files into a extensionless filename directory
        if($remoteFileName.Contains(".zip")){
            Write-Host "   - expanding archive to $toolsPath\$bareFileName" 
            Expand-Archive -Force -Path $output -DestinationPath "$toolsPath\$bareFileName"
            Write-Host "   - removing $output"
            Remove-Item -Force -Path $output
        }
    }
}

Function InstallServer{
    Write-Host "Installing Octopus Deploy server to $ServerInstallPath" -ForegroundColor Green
    $commandArgs = "/i $OctopusServerMsi /quiet INSTALLLOCATION=$ServerInstallPath /lv $toolsPath\Octopus-Server-Install-Log.txt"
    Start-Process "msiexec" $commandArgs -Wait -Verb RunAs
}

Function ConfigureServer{
    
    Write-Host "Configuring Octopus Deploy server" -ForegroundColor Green

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
    
    Write-Host "Server Installation and configuration complete" -ForegroundColor Green
    
}

Function GetSeverThumbprint{
    $response = & $Server "show-thumbprint"
    return $response[2];
}

Function InstallTentacle{
    Write-Host "Installing Octopus Deploy tentacle to $TentacleInstallPath" -ForegroundColor Green
    $commandArgs = "/i $OctopusTentacleServerMsi /quiet INSTALLLOCATION=$TentacleInstallPath /lv $toolsPath\Octopus-Tentacle-Install-Log.txt"
    Start-Process "msiexec" $commandArgs -Wait -Verb RunAs
}

Function ConfigureTentacle($thumbprint){
    Write-Host "Configuring Octopus Deploy tentacle" -ForegroundColor Green

    $commands = @(
    "create-instance --instance `"Tentacle`" --config `"$TentacleHomeDirectory\Tentacle.config`""
    ,"new-certificate --instance `"Tentacle`" --if-blank"
    ,"configure --instance `"Tentacle`" --reset-trust"
    ,"configure --instance `"Tentacle`" --home `"$TentacleHomeDirectory`" --app `"$TentacleHomeDirectory\Applications`" --port `"10933`" --noListen `"False`""
    ,"configure --instance `"Tentacle`" --trust `"$thumbprint`""
    );
    
    foreach($command in $commands){
        Write-Host $Tentacle $command -ForegroundColor Green
        Start-Process -NoNewWindow -Wait -FilePath $Tentacle -ArgumentList $command
    }
    
    Write-Host "Configuring the firewall" -ForegroundColor Yellow
    Start-Process -NoNewWindow -Wait -FilePath `"netsh`" -ArgumentList "advfirewall firewall add rule `"name=Octopus Deploy Tentacle`" dir=in action=allow  protocol=TCP localport=10933"
    
    Write-Host "Starting Tentacle" -ForegroundColor Green
    Start-Process -NoNewWindow -Wait -FilePath $Tentacle -ArgumentList "service --instance `"Tentacle`" --install --start"
    
    Write-Host "Tentacle Installation and configuration complete" -ForegroundColor Green
}

Function CreateApiKey{
    
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
    
    $ApiObj = $repository.Users.CreateApiKey($UserObj, "Clear Measure Bootcamp")
    
    #Returns the API Key in clear text
    return $ApiObj.ApiKey    
}

Function CreateOctopusEnvironments($apiKey){
    $environments = @("Dev", "QA", "Staging", "Production")
    
    foreach($environment in $environments){
        $command = "create-environment --server=$serverUrl --apiKey=$apiKey --name=`"$environment`""
        Start-Process -NoNewWindow -Wait -FilePath $Octo -ArgumentList $command
    }
}

# ** ** ** ** ** ** ** ** ** 
#  Procedural Execution
# ** ** ** ** ** ** ** ** ** 
if(Test-IsLocalAdministrator){
    Write-Host "Running Installer as Administrator" -ForegroundColor Green
}else{
    Write-Host "Not Local Admin: Please run Powershell as Administrator" -ForegroundColor Red
    exit;
}

#DownloadTools;
#InstallServer;
ConfigureServer;
#$thumbprint = GetSeverThumbprint;
#InstallTentacle;
#ConfigureTentacle($thumbprint);
#$apiKey = CreateApiKey;
#Write-Host "Created API Key: $apiKey";
#CreateOctopusEnvironments($apiKey);