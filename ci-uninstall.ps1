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

Function Test-IsLocalAdministrator {
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

Function UninstallServer{
    
    Write-Banner "Uninstalling Octopus Deploy server to $ServerInstallPath" -banner $true -color yellow
    $commandArgs = "/x $OctopusServerMsi /quiet"
    Start-Process "msiexec" $commandArgs -Wait -Verb RunAs
}

Function UninstallTentacle{
    Write-Banner "Uninstalling Octopus Deploy tentacle to $TentacleInstallPath" -banner $true -color yellow
    $commandArgs = "/x $OctopusTentacleServerMsi /quiet"
    Start-Process "msiexec" $commandArgs -Wait -Verb RunAs
}

Function UninstallOctopusDeployDatabase{
    $Server=".\sqlexpress" 
    $dbName="ClearMeasureBootcamp"         
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
    $SMOserver = New-Object ('Microsoft.SqlServer.Management.Smo.Server') -argumentlist $Server
    #$SMOserver.Databases | select Name
    if ($SMOserver.Databases[$dbName] -ne $null){
        $SMOserver.KillAllProcesses($dbName)
        $SMOserver.KillDatabase($dbName)
        Write-banner -Message "Database $dbName has been removed" -banner $true -color red
    }else{
        Write-banner -Message "Database $dbName does not exist" -banner $true -color gray
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


# ** ** ** ** ** ** ** ** ** 
#  Procedural Execution
# ** ** ** ** ** ** ** ** ** 
if(-Not (Test-IsLocalAdministrator) -eq $True){
    Write-Banner -Message "Not Local Admin: Please run Powershell as Administrator" -color red
    exit;
}

UninstallTentacle;
UninstallServer;
UninstallOctopusDeployDatabase;