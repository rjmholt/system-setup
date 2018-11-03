# Allow running the install script
Set-ExecutionPolicy RemoteSigned -Force

# Make sure the TLS version works with github
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Install PowerShell Core
$tmpdir = [System.IO.Path]::GetTempPath()
$msiPath = [System.IO.Path]::Combine($tmpdir, 'install-powershell.msi')
Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v6.1.0/PowerShell-6.1.0-win-x64.msi' -OutFile $msiPath
Start-Process -Wait 'msiexec.exe' -ArgumentList  '/i',$msiPath,'/qn','/norestart'

# Update the path to include pwsh
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
pwsh -Command "Set-ExecutionPolicy RemoteSigned -Force"

# Run the installation with PS Core
$preBuildPath = [System.IO.Path]::Combine($tmpdir, 'prebuild.ps1')
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/rjmholt/system-setup/master/prebuild.ps1' -OutFile $preBuildPath
pwsh -File $preBuildPath
