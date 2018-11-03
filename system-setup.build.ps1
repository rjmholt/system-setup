$ErrorActionPreference = 'Stop'

$script:tmpdir = [System.IO.Path]::GetTempPath()

$script:RememberToInstall = @()

class GitHubRepo
{
    [string]$Name
    [string]$Origin
    [string]$Upstream
}

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
    param(
        [Parameter()]
        [string[]]
        $NewPathElements,

        [Parameter()]
        [switch]
        $AddToEnd
    )

    $elems = @(
        [System.Environment]::GetEnvironmentVariable("Path","Machine") 
        [System.Environment]::GetEnvironmentVariable("Path","User") 
    )

    if ($NewPathElements)
    {
        if ($AddToEnd)
        {
            $elems += $NewPathElements
        }
        else
        {
            $elems = $NewPathElements + $elems
        }
    }

    $env:Path = $elems -join [System.IO.Path]::PathSeparator
}

function Restore-WebFileToTemp
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Uri,

        [Parameter(Mandatory=$true)]
        [string]
        $FileName
    )

    $path = Join-Path $script:tmpdir $FileName
    $null = Invoke-WebRequest -Uri $Uri -OutFile $path
    return $path
}

function Install-FromExe
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ExePath,

        [Parameter()]
        [string[]]
        $Arguments,

        [Parameter()]
        [switch]
        $Wait,

        [Parameter()]
        [switch]
        $RunAsUnelevated
    )

    if ($RunAsUnelevated)
    {
        Start-Process 'runas.exe' -ArgumentList "/trustlevel:0x20000 $ExePath $Arguments" -Wait:$Wait
        return
    }

    if ($Arguments)
    {
        Start-Process $ExePath -Wait:$Wait -ArgumentList $Arguments
        return
    }

    Start-Process $ExePath -Wait:$Wait
}

function Install-FromMsi
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $MsiPath,

        [Parameter()]
        [switch]
        $Wait
    )

    Start-Process 'msiexec.exe' -Wait:$Wait -ArgumentList '/i',$MsiPath,'/qn','/norestart'
}

function Install-FromPkg
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PkgPath,

        [Parameter()]
        [switch]
        $Wait
    )

    Start-Process 'installer' -ArgumentList "-pkg $PkgPath -target /" -Wait:$Wait
}

function Install-FromDmg
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $DmgPath,

        [Parameter(Mandatory=$true)]
        [string]
        $VolumeName,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('*\.app$')]
        $AppName
    )

    Start-Process -Wait 'hdiutil' -ArgumentList "attach $DmgPath"

    $appDmgPath = Join-Path '/Volumes' $VolumeName $AppName

    $appDestination = Join-Path '/Applications' $AppName

    Copy-Item -LiteralPath $appDmgPath -Destination $appDestination
}

function Install-FromWeb
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Uri,

        [Parameter(Mandatory=$true)]
        [string]
        $FileName,

        [Parameter()]
        [switch]
        $Wait,

        [Parameter(ParameterSetName='Exe')]
        [switch]
        $Exe,

        [Parameter(ParameterSetName='Msi')]
        [switch]
        $Msi,

        [Parameter(ParameterSetName='Pkg')]
        [switch]
        $Pkg,

        [Parameter(ParameterSetName='Dmg')]
        [switch]
        $Dmg,

        [Parameter(ParameterSetName='Exe')]
        [string[]]
        $Arguments,

        [Parameter(ParameterSetName='Exe')]
        [switch]
        $Unelevated,

        [Parameter(ParameterSetName='Dmg', Mandatory=$true)]
        [string]
        $VolumeName,

        [Parameter(ParameterSetName='Dmg', Mandatory=$true)]
        [string]
        $AppName
    )

    $installerPath = Restore-WebFileToTemp -Uri $Uri -FileName $FileName

    if ($Msi)
    {
        Install-FromMsi -MsiPath $installerPath -Wait:$Wait
        return
    }

    if ($Pkg)
    {
        Install-FromPkg -PkgPath $installerPath -Wait:$Wait
        return
    }

    if ($Exe)
    {
        Install-FromExe -ExePath $installerPath -Arguments $Arguments -Wait:$Wait -RunAsUnelevated:$Unelevated
        return
    }

    if ($Dmg)
    {
        Install-FromDmg -DmgPath $installerPath -VolumeName $VolumeName -AppName $AppName
        return
    }

    throw 'File format not specified'
}

function Restore-GitHubRepos
{
    param(
        [Parameter(Mandatory=$true)]
        [object]
        $Item,

        [Parameter(Mandatory=$true)]
        [string]
        $BaseDir
    )

    if (-not $Item)
    {
        return
    }

    if ($Item -is [GitHubRepo])
    {
        $repoPath = Join-Path $BaseDir $Item.Name
        git clone --recursive $Item.Origin
        Push-Location $repoPath
        try
        {
            if ($Item.Upstream)
            {
                git remote add upstream $Item.Upstream
            }
            git fetch --all
        }
        finally
        {
            Pop-Location
        }
        return
    }

    if ($Item -is [hashtable])
    {
        foreach ($dir in $Item.get_Keys())
        {
            $dirPath = Join-Path $BaseDir $dir
            Restore-GitHubRepos -Item $Item[$dir] -BaseDir $dirPath
        }
    }
}

task Homebrew -If { $IsMacOS } {
    Write-Section 'Installing Homebrew'

    $homebrewInstallPath = Restore-WebFileToTemp -FileName 'install-homebrew.rb' -Uri 'https://raw.githubusercontent.com/Homebrew/install/master/install'
    /usr/bin/ruby $homebrewInstallPath
}

task Vim Homebrew,LinuxPackages,Python,Node,Rust,Erlang,{
    Write-Section 'Installing vim'

    $vimrcLocation = if ($IsWindows) { '~/_vimrc' } else { '~/.vimrc' }
    $vimFolder = if ($IsWindows) { '~/vimfiles' } else { '~/.vim' }

    if ($IsWindows)
    {
        $vimrcSrcPath = Join-Path $PSScriptRoot 'vimrc.win.vim'
    }
    else
    {
        $vimrcSrcPath = Join-Path $PSScriptRoot 'vimrc.unix.vim'
    }

    if ($IsLinux)
    {
        apt -y install vim-gtk3
    }
    elseif ($IsMacOS)
    {
        sudo -H -u $env:SUDO_USER brew install vim --with-override-system-vi --with-python3
    }
    else
    {
        $vimExeUri = 'https://github.com/vim/vim-win32-installer/releases/download/v8.1.0454/gvim_8.1.0454_x86-mui2.exe'
        Install-FromWeb -Wait -Uri $vimExeUri -FileName 'install-vim.exe' -Arguments '/S'
        Update-Path -NewPathElements "${env:ProgramFiles(x86)}\Vim\vim81"
    }

    Copy-Item -Path $vimrcSrcPath -Destination $vimrcLocation -Force
    New-Item -Path "$vimFolder/plugged" -ItemType Directory
    New-Item -Path "$vimFolder/autoload" -ItemType Directory
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' -OutFile "$vimFolder/autoload/plug.vim"

    # Run vim-plug installations
    Start-Process 'vim' -ArgumentList '+PlugUpdate +qall'
}

task Dotnet {
    Write-Section 'Installing dotnet'

    if ($IsLinux)
    {
        wget -q 'https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb'
        dpkg -i packages-microsoft-prod.deb
        apt install -y apt-transport-https
        apt update -y
        apt install -y dotnet-sdk-2.1
    }
    elseif ($IsMacOS)
    {
        $dotnetUri = 'https://download.visualstudio.microsoft.com/download/pr/38102737-cb48-46c2-8f52-fb7102b50ae7/d81958d71c3c2679796e1ecfbd9cc903/dotnet-sdk-2.1.403-osx-x64.pkg'
        Install-FromWeb -Uri $dotnetUri -FileName 'dotnetInstaller.pkg' -Pkg -Wait
    }
    else
    {
        $dotnetInstallerPath = Restore-WebFileToTemp -FileName 'install-dotnet.ps1' -Uri 'https://dot.net/v1/dotnet-install.ps1'
        & $dotNetInstallerPath
    }
}

task VSCode {
    Write-Section 'Installing VSCode'

    $extensions = @(
        'DavidAnson.vscode-markdownlint'
        'eamodio.gitlens'
        'EditorConfig.EditorConfig'
        'eg2.tslint'
        'jchannon.csharpextensions'
        'k--kato.docomment'
        'ms-vscode.csharp'
        'vscodevim.vim'
    )

    if ($IsWindows)
    {
        $extensions += @(
            'ms-vscode.azure-account'
        )
    }
    else
    {
        $extensions += @(
            'justusadam.language-haskell'
            'alanz.vscode-hie-server'
            'rust-lang.rust'
            'pgourlain.erlang'
            'freebroccolo.reasonml'
        )
    }

    $installVSCodePath = Restore-WebFileToTemp -FileName 'Install-VSCode.ps1' -Uri 'https://raw.githubusercontent.com/PowerShell/vscode-powershell/4936994291fa39d93f29bf1b2670aaf2d06a49f0/scripts/Install-VSCode.ps1'
    & $installVSCodePath -BuildEdition 'Insider-System' -AdditionalExtensions $extensions
}

task PowerShellModules {
    Write-Section 'Installing PowerShell modules'

    # PowerShell modules to install
    $powerShellModules = @(
        @{ Name = 'posh-git'; AllowPrerelease = $true }
    )

    foreach ($m in $powerShellModules)
    {
        Install-Module @m -Scope CurrentUser
    }
}

task PowerShellProfile {
    Write-Section 'Installing PowerShell profile'

    $profileSrcPath = Join-Path $PSScriptRoot 'profile.ps1'

    $profileDir = Split-Path $PROFILE

    if (-not (Test-Path $profileDir))
    {
        New-Item -ItemType Directory $profileDir
    }

    Copy-Item -LiteralPath $profileSrcPath -Destination $PROFILE -Force
}

task Telegram {
    Write-Section 'Installing Telegram'

    if ($IsLinux)
    {
        $telegramPath = Restore-WebFileToTemp -FileName 'telegram.tar.xz' -Uri 'https://telegram.org/dl/desktop/linux'
        Push-Location $script:tmpdir
        tar xvf $telegramPath
        mv ./Telegram /opt/
        Pop-Location
        return
    }

    if ($IsWindows)
    {
        Install-FromWeb -Exe -Uri 'https://updates.tdesktop.com/tsetup/tsetup.1.4.3.exe' -FileName 'telegram-installer.exe' -Arguments '/silent'
        return
    }

    $script:RememberToInstall += 'Telegram'
}

task Spotify {
    Write-Section 'Installing Spotify'

    if ($IsLinux)
    {
        apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-keys '931FF8E79F0876134EDDBDCCA87FF9DF48BF1C90'
        'deb http://repository.spotify.com stable non-free' > /etc/apt/sources.list.d/spotify.list
        apt update -y
        apt install -y spotify-client
        return
    }

    if ($IsWindows)
    {
        Install-FromWeb -Exe -Uri 'https://download.scdn.co/SpotifySetup.exe' -FileName 'SpotifySetup.exe' -Arguments '/silent' -Unelevated
        return
    }

    $script:RememberToInstall += 'Spotify'
}

task Firefox {
    Write-Section 'Installing Firefox'

    if ($IsLinux)
    {
        apt install -y firefox
        return
    }

    if ($IsWindows)
    {
        Install-FromWeb -Exe -FileName 'ffInstaller.exe' -Uri 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US' -Arguments '/DesktopShortcut=false'
        return
    }

    $script:RememberToInstall += 'Firefox'
}

task Chrome {
    Write-Section 'Installing Chrome'

    if ($IsLinux)
    {
        $debFilePath = Join-Path $script:tmpdir 'chrome.deb'
        Invoke-WebRequest -Uri 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' -OutFile $debFilePath
        apt install $debFilePath
        return
    }

    if ($IsWindows)
    {
        Install-FromWeb -Msi -Uri 'https://cloud.google.com/chrome-enterprise/browser/download/thankyou?platform=WIN64_MSI&channel=stable&usagestats=0#' -FileName 'install-chrome.msi'
        return
    }

    $script:RememberToInstall += 'Chrome'
}

task GitHubRepos {
    Write-Section 'Setting up GitHub repos'

    if ($IsWindows)
    {
        $myGH = "https://github.com/rjmholt/{0}"
        $psGH = "https://github.com/PowerShell/{0}"
    }
    else
    {
        $myGH = "git@github.com:rjmholt/{0}"
        $psGH = "git@github.com:PowerShell/{0}"
    }

    $psRepos = @(
        'PowerShell'
        'vscode-PowerShell'
        'PowerShellEditorServices'
        'PSScriptAnalyzer'
        'EditorSyntax'
        'PowerShell-RFC'
        'PowerShell-Docs'
        'PSReadLine'
    )

    if ($global:psRepos)
    {
        $psRepos += $global:psRepos
    }

    $psRepoDetails = $psRepos | ForEach-Object { [GitHubRepo]@{ Name = $_; Origin = ($myGH -f $_); Upstream = ($psGH -f $_) } }

    $myRepos = @(
        'ModuleAnalyzer'
        'system-setup'
    )

    $myRepoDetails = $myRepos | ForEach-Object { [GitHubRepo]@{ Name = $_; Origin = ($myGH -f $_) } }

    $repos = @{
        $HOME = @{
            Documents = @{
                Dev = @{
                    Microsoft = $psRepoDetails
                    Projects = $myRepoDetails
                    sandbox = @()
                }
            }
        }
    }

    foreach ($baseDir in $repos.get_Keys())
    {
        Restore-GitHubRepos -DirStructure $repos[$baseDir] -BaseDir $baseDir
    }
}

task LinuxPackages -If { $IsLinux } {
    Write-Section 'Installing other packages'

    $packages = @(
        'build-essential'
        'haskell-platform'
        'ocaml'
        'opam'
        'openjdk-8-jdk'
        'openjdk-11-jdk'
    )

    apt update
    apt install $packages
}

task Rust -If { $IsLinux } {
    Write-Section 'Installing Rust'

    sudo -H -u $env:SUDO_USER bash -c 'curl https://sh.rustup.rs -sSf | sh -s -- -y'
}

task Node {
    Write-Section 'Installing node'

    if ($IsLinux)
    {
        apt install nodejs npm
    }
    elseif ($IsWindows)
    {
        Install-FromWeb -Msi -FileName 'install-node.msi' -Uri 'https://nodejs.org/dist/v10.13.0/node-v10.13.0-x86.msi' -Wait
    }

    Update-Path

    npm install -g typescript
}

task Python {
    if ($IsLinux)
    {
        apt install python3 ipython3
        return
    }

    if ($IsWindows)
    {
        Install-FromWeb -Exe -FileName 'install-python.exe' -Uri 'https://www.python.org/ftp/python/3.7.1/python-3.7.1-amd64.exe' -Arguments '/quiet' -Wait
        return
    }
}

task Erlang -If { $IsLinux } {
    $erlangDeb = Join-Path $script:tmpdir 'erlang.deb'
    Invoke-WebRequest -Uri 'https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb' -OutFile $erlangDeb
    dpkg -i $erlangDeb
    apt update
    apt install esl-erlang
}

task RememberToInstall -If { $script:RememberToInstall } {
    Write-Host "`n`nRemember to install the following programs:"
    foreach ($p in $script:RememberToInstall)
    {
        Write-Host "`t- $p"
    }
    Write-Host "`n"
}

task . @(
    'PowerShellModules'
    'PowerShellProfile'
    'Dotnet'
    'Node'
    'Rust'
    'LinuxPackages'
    'Vim'
    'VSCode'
    'Firefox'
    'Chrome'
    'Telegram'
    'Spotify'
    'GitHubRepos'
    'RememberToInstall'
)
