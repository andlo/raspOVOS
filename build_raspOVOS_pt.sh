#!/bin/bash
# Exit on error
# If something goes wrong just stop.
# it allows the user to see issues at once rather than having
# scroll back and figure out what went wrong.
set -e

# Activate the virtual environment
source /home/$USER/.venvs/ovos/bin/activate

echo "Downloading portuguese vosk model..."
# Download and extract VOSK model
VOSK_DIR="/home/$USER/.local/share/vosk"
mkdir -p $VOSK_DIR
wget https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip -P $VOSK_DIR
unzip -o $VOSK_DIR/vosk-model-small-pt-0.3.zip -d $VOSK_DIR
rm $VOSK_DIR/vosk-model-small-pt-0.3.zip

# remove english piper voice
EN_PIPER_DIR="/home/$USER/.local/share/piper_tts/voice-en-gb-alan-low"
rm -rf "$EN_PIPER_DIR"

# download default piper voice for portuguese
PIPER_DIR="/home/$USER/.local/share/piper_tts/tugao-medium"
VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_PT/tug%C3%A3o/medium/pt_PT-tug%C3%A3o-medium.onnx"
VOICE_URL2="https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_PT/tug%C3%A3o/medium/pt_PT-tug%C3%A3o-medium.onnx.json"
mkdir -p "$PIPER_DIR"
echo "Downloading voice from $VOICE_URL..."
wget "$VOICE_URL" -O "$PIPER_DIR/pt_PT-tugão-medium.onnx"
echo "Downloading voice config from $VOICE_URL2..."
wget "$VOICE_URL2" -O "$PIPER_DIR/pt_PT-tugão-medium.onnx.json"

echo "Creating system level mycroft.conf..."
mkdir -p /etc/mycroft

CONFIG_ARGS=""
# Loop through the MYCROFT_CONFIG_FILES variable and append each file to the jq command
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