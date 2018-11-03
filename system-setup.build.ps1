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
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
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

    $homebrewInstallPath = Join-Path $script:tmpdir 'install-homebrew.rb'
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Homebrew/install/master/install' -OutFile $homebrewInstallPath
    /usr/bin/ruby $homebrewInstallPath
}

task Vim Homebrew,LinuxPackages,Python,Node,Rust,Erlang {
    Write-Section 'Installing vim'

    $vimrcLocation = if ($IsWindows) { '~/_vimrc' } else { '~/.vimrc' }
    $vimFolder = if ($IsWindows) { '~/vimfiles' } else { '~/.vim' }

    $vimrcSrcPath = Join-Path $PSScriptRoot (if ($IsWindows) { 'vimrc.win.vim' } else { 'vimrc.unix.vim' })

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
        $vimExePath = Join-Path $script:tmpdir 'install-vim.exe'
        Invoke-WebRequest -Uri 'https://github.com/vim/vim-win32-installer/releases/download/v8.1.0454/gvim_8.1.0454_x86-mui2.exe' -OutFile $vimExePath
        Start-Process -Wait $vimExePath -ArgumentList '/S'
    }

    Update-Path

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
        $dotNetInstallerPath = Join-Path $script:tmpdir 'dotnetInstaller.pkg'
        Invoke-WebRequest -Uri 'https://download.visualstudio.microsoft.com/download/pr/38102737-cb48-46c2-8f52-fb7102b50ae7/d81958d71c3c2679796e1ecfbd9cc903/dotnet-sdk-2.1.403-osx-x64.pkg' -OutFile $dotNetInstallerPath
        installer -pkg $dotNetInstallerPath -target /
    }
    else
    {
        $dotnetInstallerPath = Join-Path $script:tmpdir 'install-dotnet.ps1'
        Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile $dotNetInstallerPath
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

    $installVSCodePath = Join-Path $script:tmpdir 'Install-VSCode.ps1'
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/PowerShell/vscode-powershell/4936994291fa39d93f29bf1b2670aaf2d06a49f0/scripts/Install-VSCode.ps1' -OutFile $installVSCodePath
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
        $telegramDl = Join-Path $script:tmpdir 'telegram.tar.xz'
        Invoke-WebRequest -Uri 'https://telegram.org/dl/desktop/linux' -OutFile $telegramDl
        Push-Location $script:tmpdir
        tar xvf $telegramDl
        mv ./Telegram /opt/
        Pop-Location
        return
    }

    if ($IsWindows)
    {
        $telegramInstaller = Join-Path $script:tmpdir 'telegram-installer.exe'
        Invoke-WebRequest -Uri 'https://updates.tdesktop.com/tsetup/tsetup.1.4.3.exe' -OutFile $telegramInstaller
        Start-Process -Wait $telegramInstaller -ArgumentList '/silent'
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
        $spotInstallerPath = Join-Path $script:tmpdir 'SpotifySetup.exe'
        Invoke-WebRequest -Uri 'https://download.scdn.co/SpotifySetup.exe' -OutFile $spotInstallerPath
        Start-Process -Wait 'runas.exe' -ArgumentList "/trustlevel:0x20000 '$spotInstallerPath /silent'"
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
        $ffInstallerPath = Join-Path $script:tmpdir 'ffInstaller.exe'
        Invoke-WebRequest -Uri 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US' -OutFile $ffInstallerPath
        Start-Process -Wait $ffInstallerPath -ArgumentList '/DesktopShortcut=false'
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
        $chromiumInstallerPath = Join-Path $script:tmpdir 'install-chrome.exe'
        Invoke-WebRequest -Uri 'https://github.com/henrypp/chromium/releases/download/v70.0.3538.77-r587811-win64/chromium-sync.exe' -OutFile $chromiumInstallerPath
        Start-Process $chromiumInstallerPath -ArgumentList '/silent'
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
        $nodeInstallerPath = Join-Path $script:tmpdir 'install-node.msi'
        Invoke-WebRequest -Uri 'https://nodejs.org/dist/v10.13.0/node-v10.13.0-x86.msi' -OutFile $nodeInstallerPath
        Start-Process 'msiexec.exe' -Wait -ArgumentList "/qn /i $nodeInstallerPath"
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
        $pythonInstallerPath = Join-Path $script:tmpdir 'install-python.exe'
        Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.7.1/python-3.7.1-amd64.exe' -OutFile $pythonInstallerPath
        Start-Process -Wait $pythonInstallerPath -ArgumentList '/quiet'
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
    PowerShellModules
    PowerShellProfile
    Dotnet
    Node
    Rust
    LinuxPackages
    Vim
    VSCode
    Firefox
    Chrome
    Telegram
    Spotify
    GitHubRepos
    RememberToInstall
)
