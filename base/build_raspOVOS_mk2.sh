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
pip3 install git+https://github.com/NeonGeckoCom/sj201-interface

# VocalFusion SJ201 drivers
cd /home/ovos
git clone https://github.com/OpenVoiceOS/VocalFusionDriver
cd VocalFusionDriver/driver
make all
kernel=$(uname -r)
mkdir -p "/lib/modules/${kernel}/kernel/drivers/vocalfusion"
cp vocalfusion* "/lib/modules/${kernel}/kernel/drivers/vocalfusion"
cd /home/ovos
rm -rf VocalFusionDriver
depmod "${kernel}" -a

# cp -v /mounted-github-repo/mark2/files/sj201-daemon.conf "/etc/pulse/daemon.conf.d/sj201-daemon.conf"
# chmod 0644 /etc/pulse/daemon.conf.d/sj201-daemon.conf
# cp -v /mounted-github-repo/mark2/files/92-sj201-default.pa "/etc/pulse/default.pa.d/92-sj201-default.pa"
# chmod 0644 /etc/pulse/default.pa.d/92-sj201-default.pa
cp -v /mounted-github-repo/mark2/files/91-vocalfusion.rules "/etc/udev/rules.d/91-vocalfusion.rules"
chmod 0644 /etc/udev/rules.d/91-vocalfusion.rules
cp -v /mounted-github-repo/mark2/files/xvf3510.conf "/usr/share/pulseaudio/alsa-mixer/profile-sets/xvf3510.conf"
chmod 0644 /usr/share/pulseaudio/alsa-mixer/profile-sets/xvf3510.conf
cp -v /mounted-github-repo/mark2/files/xvf3510-flash "/usr/libexec/xvf3510-flash"
chmod 0755 /usr/libexec/xvf3510-flash
# cp -v /mounted-github-repo/mark2/files/xvf3510.dtbo "/boot/firmware/overlays/xvf3510.dtbo"
# chmod 0644 "/boot/firmware/overlays/xvf3510.dtbo"
chmod 0755 "/usr/lib/firmware"
chmod 0755 "/usr/lib/firmware/xvf3510"
cp -v /mounted-github-repo/mark2/files/app_xvf3510_int_spi_boot_v4_2_0.bin "/usr/lib/firmware/xvf3510/app_xvf3510_int_spi_boot_v4_2_0.bin"
chmod 0644 "/usr/lib/firmware/xvf3510/app_xvf3510_int_spi_boot_v4_2_0.bin"
cp -v /mounted-github-repo/mark2/files/sj201-reset-led "/usr/bin/sj201-reset-led"
chmod 0755 /usr/bin/sj201-reset-led
cp -v /mounted-github-repo/mark2/files/tas5806-init "${ROOTFS_DIR}/usr/bin/tas5806-init"
chmod 0755 "${ROOTFS_DIR}/usr/bin/tas5806-init"

# pip3 install git+https://github.com/NeonGeckoCom/neon-phal-plugin-linear_led
# pip3 install git+https://github.com/NeonGeckoCom/neon-phal-plugin-switches
# pip3 install git+https://github.com/NeonGeckoCom/neon-phal-plugin-fan

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