#!/bin/bash
# Exit on error
# If something goes wrong just stop.
# it allows the user to see issues at once rather than having
# scroll back and figure out what went wrong.
set -e

echo "Customizing boot/firmware/config.txt..."
cp -v /mounted-github-repo/patches/boot_config.txt /boot/firmware/config.txt

# Activate the virtual environment
source /home/$USER/.venvs/ovos/bin/activate

echo "Installing mk2 plugins and skills..."
uv pip install --no-progress ovos-PHAL[mk2] -c $CONSTRAINTS

# Install mk2 drivers
#!/bin/bash

set -e

# Variables
OVOS_HARDWARE_MARK2_VOCALFUSION_REPO_URL="https://github.com/OpenVoiceOS/VocalFusionDriver/"
OVOS_HARDWARE_MARK2_VOCALFUSION_SRC_PATH="/home/$USER/VocalFusionDriver"
OVOS_HARDWARE_MARK2_VOCALFUSION_BRANCH="main"
RPI_VERSION="Raspberry Pi 4" # Adjust this based on your Raspberry Pi version
#OVOS_INSTALLER_USER_HOME="/home/ovos"
#OVOS_INSTALLER_USER="your_user_here"
#OVOS_INSTALLER_GROUP="your_group_here"
KERNEL=$(ls -1 /lib/modules | sort -V | tail -n 1)
PROCESSOR_COUNT=$(nproc)
BOOT_DIRECTORY="/boot"

# Clone VocalFusionDriver Git repository
git clone --branch "$OVOS_HARDWARE_MARK2_VOCALFUSION_BRANCH" "$OVOS_HARDWARE_MARK2_VOCALFUSION_REPO_URL" "$OVOS_HARDWARE_MARK2_VOCALFUSION_SRC_PATH"

# Copy DTBO files to /boot/overlays
IS_RPI5=""
if [[ "$RPI_VERSION" == *"Raspberry Pi 5"* ]]; then
  IS_RPI5="-pi5"
fi
for DTBO_FILE in sj201 sj201-buttons-overlay sj201-rev10-pwm-fan-overlay; do
  cp "$OVOS_HARDWARE_MARK2_VOCALFUSION_SRC_PATH/$DTBO_FILE$IS_RPI5.dtbo" "/boot/overlays/"
done

# Manage sj201, buttons, and PWM overlays
for DTO_OVERLAY in sj201 sj201-buttons-overlay sj201-rev10-pwm-fan-overlay; do
  if ! grep -q "^dtoverlay=$DTO_OVERLAY$IS_RPI5" "$BOOT_DIRECTORY/config.txt"; then
    echo "dtoverlay=$DTO_OVERLAY$IS_RPI5" >> "$BOOT_DIRECTORY/config.txt"
  fi
done

# Build vocalfusion-soundcard.ko kernel module
cd "$OVOS_HARDWARE_MARK2_VOCALFUSION_SRC_PATH/driver"
make -j "$PROCESSOR_COUNT" KDIR="/lib/modules/$KERNEL/build" all

# Copy vocalfusion-soundcard.ko to /lib/modules/$KERNEL
cp "$OVOS_HARDWARE_MARK2_VOCALFUSION_SRC_PATH/driver/vocalfusion-soundcard.ko" "/lib/modules/$KERNEL/vocalfusion-soundcard.ko"
depmod

# Create /etc/modules-load.d/vocalfusion.conf file
echo "vocalfusion-soundcard" > /etc/modules-load.d/vocalfusion.conf

# Install packages
pip install Adafruit-Blinka smbus2 RPi.GPIO gpiod

# Download SJ201 firmware and scripts
mkdir -p /opt/sj201
curl -o /opt/sj201/xvf3510-flash "https://raw.githubusercontent.com/OpenVoiceOS/ovos-buildroot/0e464466194f58553af11c34f7435dba76ec70a3/buildroot-external/package/vocalfusion/xvf3510-flash"
chmod 0755 /opt/sj201/xvf3510-flash
curl -o /opt/sj201/app_xvf3510_int_spi_boot_v4_2_0.bin "https://raw.githubusercontent.com/OpenVoiceOS/ovos-buildroot/c67d7f0b7f2a3eff5faab96d6adf7495e9b48b93/buildroot-external/package/vocalfusion/app_xvf3510_int_spi_boot_v4_2_0.bin"
chmod 0755 /opt/sj201/app_xvf3510_int_spi_boot_v4_2_0.bin
curl -o /opt/sj201/init_tas5806 "https://raw.githubusercontent.com/MycroftAI/mark-ii-hardware-testing/main/utils/init_tas5806.py"
chmod 0755 /opt/sj201/init_tas5806

# Copy SJ201 systemd unit file
cat <<EOF > "$OVOS_INSTALLER_USER_HOME/.config/systemd/user/sj201.service"
[Unit]
Description=SJ201 Service

[Service]
ExecStart=/opt/sj201/xvf3510-flash
EOF
chown "$OVOS_INSTALLER_USER:$OVOS_INSTALLER_GROUP" "$OVOS_INSTALLER_USER_HOME/.config/systemd/user/sj201.service"
chmod 0644 "$OVOS_INSTALLER_USER_HOME/.config/systemd/user/sj201.service"

# Enable SJ201 systemd unit
sudo -u "$OVOS_INSTALLER_USER" systemctl --user enable sj201.service --force

# Delete source path once compiled
rm -rf "$OVOS_HARDWARE_MARK2_VOCALFUSION_SRC_PATH"





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