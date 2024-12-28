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

echo "Installing SJ201 drivers..."
# Variables
RPI_VERSION="Raspberry Pi 4" # Adjust this based on your Raspberry Pi version
#OVOS_INSTALLER_USER_HOME="/home/ovos"
#OVOS_INSTALLER_USER="your_user_here"
#OVOS_INSTALLER_GROUP="your_group_here"
KERNEL=$(ls -1 /lib/modules | sort -V | tail -n 1)
PROCESSOR_COUNT=$(nproc)
BOOT_DIRECTORY="/boot"

# Clone VocalFusionDriver Git repository
echo "Cloning VocalFusionDriver Git repository..."
git clone https://github.com/OpenVoiceOS/VocalFusionDriver/ /home/$USER
cd /home/$USER/VocalFusionDriver/

# Copy DTBO files to /boot/overlays
echo "Copying DTBO files to /boot/overlays..."
IS_RPI5=""
if [[ "$RPI_VERSION" == *"Raspberry Pi 5"* ]]; then
  IS_RPI5="-pi5"
fi
for DTBO_FILE in sj201 sj201-buttons-overlay sj201-rev10-pwm-fan-overlay; do
  cp "$DTBO_FILE$IS_RPI5.dtbo" "/boot/overlays/"
done

# Manage sj201, buttons, and PWM overlays
echo "Managing sj201, buttons, and PWM overlays..."
for DTO_OVERLAY in sj201 sj201-buttons-overlay sj201-rev10-pwm-fan-overlay; do
  if ! grep -q "^dtoverlay=$DTO_OVERLAY$IS_RPI5" "$BOOT_DIRECTORY/config.txt"; then
    echo "dtoverlay=$DTO_OVERLAY$IS_RPI5" >> "$BOOT_DIRECTORY/config.txt"
  fi
done

cd /home/$USER

# Create script to update VocalFusionDriver kernel module if the kernel is updated
echo "Creating script to update VocalFusionDriver kernel module if the kernel is updated..."
cat <<EOF > /usr/local/bin/update_vocalfusiondriver_if_kernel_updated.sh
#!/bin/bash

set -e

# Define the path to the kernel module source
MODULE_SRC_PATH="/home/$USER/VocalFusionDriver/driver" 

# File to store the last kernel version
KERNEL_VERSION_FILE="/var/lib/vocalfusion/last_kernel_version"

# Create directory for storing the kernel version if it doesn't exist
mkdir -p /var/lib/vocalfusion

# Get the current kernel version
current_kernel=$(uname -r)

# Check if the kernel version file exists
if [ -f "$KERNEL_VERSION_FILE" ]; then
  last_kernel=$(cat "$KERNEL_VERSION_FILE")
else
  last_kernel=""
fi

# If the kernel has been updated, or this is the first run, build and install the module
if [ "$current_kernel" != "$last_kernel" ]; then
  echo "New kernel detected or first run. Building module for kernel $current_kernel."
  
  rm -rf "$MODULE_SRC_PATH"
  mkdir -p "$MODULE_SRC_PATH"
  git clone https://github.com/OpenVoiceOS/VocalFusionDriver/ "$MODULE_SRC_PATH"
  
  cd "$MODULE_SRC_PATH"/driver
  make clean
  make -j$(nproc) KDIR=/lib/modules/$current_kernel/build

  # Install the compiled module
  cp vocalfusion-soundcard.ko /lib/modules/$current_kernel/
  depmod -a

  # Update the kernel version file
  echo "$current_kernel" > "$KERNEL_VERSION_FILE"

  echo "Module compiled and installed for kernel $current_kernel."
else
  echo "Kernel version has not changed. No need to rebuild the module."
fi
EOF
chmod +x /usr/local/bin/update_vocalfusiondriver_if_kernel_updated.sh

# Create systemd service for updating VocalFusionDriver kernel module
echo "Creating systemd service for updating VocalFusionDriver kernel module..."
cat <<EOF > /etc/systemd/system/update-vocalfusiondriver.service
[Unit]
Description=Update VocalFusionDriver kernel module
After=network.target 
[Service] 
Type=oneshot 
ExecStart=/usr/local/bin/update_vocalfusiondriver_if_kernel_updated.sh
[Install] 
WantedBy=multi-user.target
EOF
chmod 644 /etc/systemd/system/update-vocalfusiondriver.service

# Create /etc/modules-load.d/vocalfusion.conf file
echo "Creating /etc/modules-load.d/vocalfusion.conf file..."
echo "vocalfusion-soundcard" > /etc/modules-load.d/vocalfusion.conf

# Install packages
echo "Installing required packages..."
pip install Adafruit-Blinka smbus2 RPi.GPIO gpiod

# Download SJ201 firmware and scripts
echo "Downloading SJ201 firmware and scripts..."
mkdir -p /opt/sj201
curl -o /opt/sj201/xvf3510-flash "https://raw.githubusercontent.com/OpenVoiceOS/ovos-buildroot/0e464466194f58553af11c34f7435dba76ec70a3/buildroot-external/package/vocalfusion/xvf3510-flash"
chmod 0755 /opt/sj201/xvf3510-flash
curl -o /opt/sj201/app_xvf3510_int_spi_boot_v4_2_0.bin "https://raw.githubusercontent.com/OpenVoiceOS/ovos-buildroot/c67d7f0b7f2a3eff5faab96d6adf7495e9b48b93/buildroot-external/package/vocalfusion/app_xvf3510_int_spi_boot_v4_2_0.bin"
chmod 0755 /opt/sj201/app_xvf3510_int_spi_boot_v4_2_0.bin
curl -o /opt/sj201/init_tas5806 "https://raw.githubusercontent.com/MycroftAI/mark-ii-hardware-testing/main/utils/init_tas5806.py"
chmod 0755 /opt/sj201/init_tas5806

# Copy SJ201 systemd unit file
echo "Copying SJ201 systemd unit file..."
cat <<EOF > /home/$USER/.config/systemd/user/sj201.service"
[Unit]
Description=SJ201 Service

[Service]
ExecStart=/opt/sj201/xvf3510-flash
EOF
chown "$USER:$USER" "/home/$USER/.config/systemd/user/sj201.service"
chmod 0644 "/home/$USER/.config/systemd/user/sj201.service"

# Enable SJ201 systemd unit
echo "Enabling SJ201 systemd unit..."
sudo -u "$USER" systemctl --user enable sj201.service --force

# Delete source path once compiled
echo "Deleting source path once compiled..."
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