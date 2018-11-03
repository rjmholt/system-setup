Set-PSReadLineOption -EditMode Vi

if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6)
{
    # Get (sort-of) bash-style partial completions in Windows
    Set-PSReadLineKeyHandler -Key Tab -Function Complete

    # Get ildasm on the path
    $env:PATH += ';Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.7.1 Tools'

    # Put vim on the path
    $env:PATH += ';Program Files (x86)\Vim\vim81'
}

Import-Module posh-git

$GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`n'