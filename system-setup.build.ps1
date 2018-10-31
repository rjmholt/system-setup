$ErrorActionPreference = 'Stop'

# PowerShell modules to install
$script:PowerShellModules = @(
    @{ Name = 'posh-git'; AllowPrerelease = $true }
)

$script:tmpdir = [System.IO.Path]::GetTempPath()

$script:VimrcPath = Join-Path $PSScriptRoot 'vimrc.vim'

task Homebrew -If { $IsMacOS } {
    $homebrewInstallPath = Join-Path $script:tmpdir 'install-homebrew.rb'
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Homebrew/install/master/install' -OutFile $homebrewInstallPath
    /usr/bin/ruby $homebrewInstallPath
}

task Vim -After Homebrew {
    $vimrcLocation = if ($IsWindows) { '~/_vimrc' } else { '~/.vimrc' }
    $vimFolder = if ($IsWindows) { '~/vimfiles' } else { '~/.vim' }

    if ($IsLinux)
    {
        apt -y install vim-gtk3
    }
    elseif ($IsMacOS)
    {
        brew install vim --with-override-system-vi --with-python3
    }
    else
    {
        $vimExePath = Join-Path $script:tmpdir 'install-vim.exe'
        Invoke-WebRequest -Uri 'ftp://ftp.vim.org/pub/vim/pc/gvim81.exe' -OutFile $vimExePath
        & $vimExePath /S
    }

    Copy-Item -Path $script:VimrcPath -Destination $vimrcLocation -Force
    New-Item -Path "$vimFolder/plugged" -ItemType Directory
    New-Item -Path "$vimFolder/autoload" -ItemType Directory
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' -OutFile "$vimFolder/autoload/plug.vim"
}

task Dotnet {
    if ($IsLinux)
    {
        wget -q 'https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb'
        dpkg -i packages-microsoft-prod.deb
        apt-get -y install apt-transport-https
        apt-get -y update
        apt-get -y install dotnet-sdk-2.1
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
    $installVSCodePath = Join-Path $script:tmpdir 'Install-VSCode.ps1'
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/PowerShell/vscode-powershell/master/scripts/Install-VSCode.ps1' -OutFile $installVSCodePath
    & $installVSCodePath -BuildEdition 'Insider-System'
}

task PowerShellModules {
    foreach ($m in $script:PowerShellModules)
    {
        Install-Module @m -Scope CurrentUser
    }
}

task Telegram {
    if ($IsLinux)
    {
        $telegramDl = Join-Path $script:tmpdir 'telegram.tar.xz'
        Invoke-WebRequest -Uri 'https://telegram.org/dl/desktop/linux' -OutFile $telegramDl
        Push-Location $script:tmpdir
        tar xvf $telegramDl
        mv ./Telegram /opt/
        Pop-Location
    }
}

task . PowerShellModules,Dotnet,VSCode,Vim,Telegram
