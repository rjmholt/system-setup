$script:tmpdir = [System.IO.Path]::GetTempPath()

function Write-Section
{
    param(
        [Parameter()]
        [string]
        $Info
    )

    Write-Host "`n`n--- $Info ---`n"
}

function Update-Path
{
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
}

function Install-InvokeBuild
{
    Write-Section "Installing InvokeBuild"

    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module -Scope CurrentUser InvokeBuild
}

function Install-Git
{
    Write-Section "Installing git"

    if ($IsLinux)
    {
        apt install -y git
        return
    }

    if ($IsMacOS)
    {
        if (-not (which git))
        {
            throw "git installation required for installation to proceed..."
        }
    }

    $gitInstallerName = 'install-git.exe'
    $gitInstallerPath = Join-Path $script:tmpdir $gitInstallerName
    Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.19.1.windows.1/Git-2.19.1-32-bit.exe' -OutFile $gitInstallerPath
    Start-Process -Wait $gitInstallerPath -ArgumentList '/silent'
    Update-Path
}

function Restore-SetupRepo
{
    Write-Section "Cloning setup repo"

    $setupPath = Join-Path $script:tmpdir 'system-setup'
    git clone 'https://github.com/rjmholt/system-setup' $setupPath > $null
    return $setupPath
}

# Install InvokeBuild
Install-InvokeBuild

# Install git
Install-Git

# Download setup repo
$setupPath = Restore-SetupRepo

# Run installation
Push-Location $setupPath
try
{
    Write-Section "Running main build"
    Invoke-Build
}
finally
{
    Pop-Location
}