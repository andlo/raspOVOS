#!/bin/bash
# Exit on error
# If something goes wrong just stop.
# it allows the user to see issues at once rather than having
# scroll back and figure out what went wrong.
set -e


# Activate the virtual environment
source /home/$USER/.venvs/ovos/bin/activate

echo "Setting up default wifi country..."
/usr/bin/raspi-config nonint do_wifi_country ES

# Install aditional packages
apt-get install -y cmake

echo "Installing AhoTTS"
uv pip install --no-progress ovos-tts-plugin-ahotts
git clone https://github.com/aholab/AhoTTS /tmp/AhoTTS
cd /tmp/AhoTTS
./script_compile_all_linux.sh
mv /tmp/AhoTTS/bin /usr/bin/AhoTTS/
cd ~

# Caching pre-trained padatious intents
echo "Caching pre-trained padatious intents..."
mkdir -p /home/$USER/.local/share/mycroft/intent_cache
if [ -d "/mounted-github-repo/$INTENT_CACHE" ]; then
  echo "Copying intent_cache directory..."
  cp -rv "/mounted-github-repo/$INTENT_CACHE" "/home/$USER/.local/share/mycroft/intent_cache/"
else
  echo "intent_cache directory does not exist. Skipping copy."
fi

# TODO TTS and STT
echo "Creating system level mycroft.conf..."
mkdir -p /etc/mycroft

# Loop through the MYCROFT_CONFIG_FILES variable and append each file to the jq command
CONFIG_ARGS=""
IFS=',' read -r -a config_files <<< "$MYCROFT_CONFIG_FILES"
for file in "${config_files[@]}"; do
  CONFIG_ARGS="$CONFIG_ARGS /mounted-github-repo/$file"
done
# Execute the jq command and merge the files into mycroft.conf
jq -s 'reduce .[] as $item ({}; . * $item)' $CONFIG_ARGS > /etc/mycroft/mycroft.conf


echo "Ensuring permissions for $USER user..."
# Replace 1000:1000 with the correct UID:GID if needed
chown -R 1000:1000 /home/$USER

echo "Cleaning up apt packages..."
apt-get --purge autoremove -y && apt-get clean