#!/bin/bash

set -e

# Define the path to the kernel module source
MODULE_SRC_PATH="/path/to/VocalFusionDriver/driver" # Update this path

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
  
  # Cross-compile the kernel module
  cd "$MODULE_SRC_PATH"
  make clean
  make -j$(nproc) KDIR=/lib/modules/$current_kernel/build

  # Install the compiled module
  sudo cp vocalfusion-soundcard.ko /lib/modules/$current_kernel/
  sudo depmod -a

  # Update the kernel version file
  echo "$current_kernel" > "$KERNEL_VERSION_FILE"

  echo "Module compiled and installed for kernel $current_kernel."
else
  echo "Kernel version has not changed. No need to rebuild the module."
fi
