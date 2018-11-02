# Install PowerShell Core
$tmpdir = [System.IO.Path]::GetTempPath()
$installScript = [System.IO.Path]::Combine($tmpdir, 'install-powershell.ps1')
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/install-powershell.ps1' -OutFile $installScript
& $installScript

# Update the path to include pwsh
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

$preBuildPath = [System.IO.Path]::Combine($tmpdir, 'prebuild.ps1')
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/rjmholt/system-setup/master/prebuild.ps1' -OutFile $preBuildPath

# Run the installation with PS Core
pwsh -File $preBuildPath
