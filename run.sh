set -e

# Install curl if it does not exist
if ! [ -x "$(command -v curl)" ]
then
    apt install -y curl
fi

if ! [ -x "$(command -v ssh)" ]
then
    apt install -y ssh
fi

if ! [ -e ~/.ssh/id_*.pub ]
then
    echo "You need to set up your ssh key and run this script again" > &2
    exit 1
fi

# Install PowerShell Core
bash <(curl -s https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/install-powershell.sh)

# Find the temp dir on the platform
for TEMP in "$TMPDIR" "$TMP" /var/tmp /tmp
do
    test -d "$TEMP" && break
done

# Download the prebuild script
PREBUILD="$TEMP/prebuild.ps1"
curl -sS 'https://raw.githubusercontent.com/rjmholt/system-setup/master/prebuild.ps1' -o "$PREBUILD"

# Run the setup
pwsh -File "$PREBUILD"