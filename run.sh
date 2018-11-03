set -e

if ! [ -x "$(command -v ssh)" ]
then
    apt install -y ssh
fi

if ! [ -e ~/.ssh/id_*.pub ]
then
    echo "You need to set up your ssh key and run this script again" >&2
    exit 1
fi

# Register the authenticity of GitHub
ssh-keyscan github.com >> ~/.ssh/known_hosts

# Install PowerShell Core
bash <(wget -q -O - https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/install-powershell.sh)

# Find the temp dir on the platform
for TEMP in "$TMPDIR" "$TMP" /var/tmp /tmp
do
    test -d "$TEMP" && break
done

# Download the prebuild script
PREBUILD="$TEMP/prebuild.ps1"
wget -q 'https://raw.githubusercontent.com/rjmholt/system-setup/master/prebuild.ps1' -O "$PREBUILD"

# Run the setup
pwsh -File "$PREBUILD"
