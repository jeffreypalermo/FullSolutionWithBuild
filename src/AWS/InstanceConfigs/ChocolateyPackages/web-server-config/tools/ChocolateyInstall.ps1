try {

Update-SessionEnvironment
$strSiteName = 'BootCamp'
$strAppPath = 'D:\Sites\BootCamp'
$toolsDirectory = 'C:\Tools'

# rename the server to include the environment type name
if(Test-Path ENV:ENVIRONMENT_TYPE)
{
	Write-Output 'Setting Computer Name to match Environment Type'
	$environment = $env:ENVIRONMENT_TYPE
	# use the tail of guid so we have a unique name
	$newName = $environment + '-' + ([system.guid]::NewGuid().ToString()).Substring(30)
	Rename-Computer -NewName $newName
}

# To see the full list of Windows features type "clist -source windowsfeatures"
Install-WindowsFeature Telnet-Client
Install-WindowsFeature Web-Server
Install-WindowsFeature Web-WebServer
Install-WindowsFeature Web-Common-Http
Install-WindowsFeature Web-Default-Doc
Install-WindowsFeature Web-Dir-Browsing
Install-WindowsFeature Web-Http-Errors
Install-WindowsFeature Web-Static-Content
Install-WindowsFeature Web-Http-Redirect
Install-WindowsFeature Web-Health
Install-WindowsFeature Web-Http-Logging
Install-WindowsFeature Web-Performance
Install-WindowsFeature Web-Stat-Compression
Install-WindowsFeature Web-Security
Install-WindowsFeature Web-Filtering
Install-WindowsFeature Web-App-Dev
Install-WindowsFeature Web-Net-Ext
Install-WindowsFeature Web-Net-Ext45
Install-WindowsFeature Web-Asp-Net
Install-WindowsFeature Web-Asp-Net45
Install-WindowsFeature Web-ISAPI-Ext
Install-WindowsFeature Web-ISAPI-Filter
Install-WindowsFeature Web-Mgmt-Tools
Install-WindowsFeature Web-Mgmt-Console
Install-WindowsFeature MSMQ-Server

cinst fiddler4 -y
cinst 7zip -y

Import-Module WebAdministration

#Disable automatic updates
Write-Output 'Disble Windows Automatic Updates'
Stop-Service -Name 'wuauserv'
Set-Service -Name 'wuauserv' -StartupType Disabled

Write-Output 'Create Services Directory'
mkdir -ErrorAction SilentlyContinue $strAppPath

Write-Output 'Create Tools Directory'
mkdir -ErrorAction SilentlyContinue $toolsDirectory

#Create some handy shortcuts
Install-ChocolateyPinnedTaskBarItem "$env:windir\system32\inetsrv\InetMgr.exe"

Write-Output 'Registering asp.net with IIS.'
$net40Path = [System.IO.Path]::Combine($env:SystemRoot, 'Microsoft.NET\Framework\v4.0.30319')
$aspnetRegIISFullName = [System.IO.Path]::Combine($net40Path, 'aspnet_regiis.exe');
start-process -filepath $aspnetRegIISFullName  -argumentlist '-i';

Write-Output 'Starting Site Setup Procedures'

#stop the default site
if(Test-Path 'IIS:\Sites\Default Web Site')
{
		Set-ItemProperty 'IIS:\Sites\Default Web Site' ServerAutoStart False
}

Write-Output 'Setting up Application Pool'
#Navigate to the app pools root
cd IIS:\AppPools\

#check to see if the app pool exists
if (!(Test-Path $strSiteName -pathType container))
{
	#create the app pool
	New-WebAppPool -Name $strSiteName
	$AppPool = Get-Item IIS:\AppPools\$strSiteName
	$appPool | Set-ItemProperty -Name 'managedRuntimeVersion' -Value 'v4.0'
	$appPool.startMode = 'AlwaysRunning'
	$AppPool.autoStart = 'true'
	$AppPool.processModel.idleTimeout = [TimeSpan]::FromMinutes(0)
	$AppPool | Set-Item
	Start-WebAppPool -name $strSiteName
	Write-Output 'Application Pool created/configured successfully.'
}

#Check for the main site to already exist
If (Get-Website | where{$_.Name -eq $strSiteName})
{
	Write-Output "$strSiteName already exists. Moving on..."
}
else
{
	#It Doesn't exist so we will create it.
	Write-Output "Creating the main site - $strSiteName"
	New-Website -Name $strSiteName -ApplicationPool $strSiteName -PhysicalPath $strAppPath -Port 80
	Write-Output 'Website/applications created successfully.'
}

#Remove HTTP Response Header
Write-Output 'Removing X-Powered-By header from IIS.'
Remove-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/httpProtocol/customHeaders -Name . -AtElement @{name='X-Powered-By'}
} catch {
  throw $_.Exception.Message
}
