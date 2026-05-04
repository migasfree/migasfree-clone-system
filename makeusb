#!/bin/bash

# Migasfree Clone System - USB Writer
# This script writes the MCS bootable ISO image to a physical USB drive using dd.

if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (sudo)."
   exit 1
fi

# Functions
# ---------

detect_usb_list() {
    local disks=$(lsblk -d -o NAME,TYPE 2>/dev/null | grep disk | awk '{print $1}')
    for disk in $disks; do
        if udevadm info --query=property --name="/dev/$disk" | grep -q "ID_BUS=usb"; then
            local size=$(lsblk -d -no SIZE "/dev/$disk" 2>/dev/null)
            local model=$(lsblk -d -no MODEL "/dev/$disk" 2>/dev/null)
            # Get labels from the disk and its partitions, taking the first non-empty one
            local label=$(lsblk -no LABEL "/dev/$disk" 2>/dev/null | grep -v "^$" | head -n 1)
            local label_str=""
            [ -n "$label" ] && label_str=" [LABEL: $label]"
            echo "/dev/$disk ($size - $model)$label_str"
        fi
    done
}

is_usb() {
    local dev=$1
    udevadm info --query=property --name="$dev" | grep -q "ID_BUS=usb"
}

# Main Logic
# ----------

DEVICE=$1

if [[ -z "$DEVICE" ]]; then
    echo "No device specified. Detecting USB drives..."
    
    # Pre-check if any USB exists
    if [[ -z $(detect_usb_list) ]]; then
        echo "Error: No USB drives detected."
        echo "Usage: sudo $0 /dev/sdX"
        exit 1
    fi

    echo "Detected USB drives:"
    # Use a custom separator to handle spaces in model names
    mapfile -t DISKS < <(detect_usb_list)
    
    for i in "${!DISKS[@]}"; do
        echo "  $((i+1))) ${DISKS[$i]}"
    done
    echo ""
    
    if [ "${#DISKS[@]}" -eq 1 ]; then
        DEFAULT_DEV=$(echo "${DISKS[0]}" | awk '{print $1}')
        read -p "Select device number [1] ($DEFAULT_DEV): " CHOICE
        CHOICE=${CHOICE:-1}
    else
        read -p "Select device number: " CHOICE
    fi
    
    # Validate selection
    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -le "${#DISKS[@]}" ] && [ "$CHOICE" -gt 0 ]; then
        DEVICE=$(echo "${DISKS[$((CHOICE-1))]}" | awk '{print $1}')
    else
        echo "Error: Invalid selection."
        exit 1
    fi
fi

if [[ ! -b "$DEVICE" ]]; then
    echo "Error: $DEVICE is not a valid block device."
    exit 1
fi

# Safety check: Is it really a USB?
if ! is_usb "$DEVICE" 2>/dev/null; then
    echo "---------------------------------------------------"
    echo "WARNING: $DEVICE DOES NOT APPEAR TO BE A USB DRIVE!"
    echo "It might be an internal disk or an SD card."
    echo "---------------------------------------------------"
    read -p "Are you SURE you want to continue with a non-USB disk? (y/N): " OVERRIDE
    if [[ "$OVERRIDE" != "y" && "$OVERRIDE" != "Y" ]]; then
        echo "Aborted for safety."
        exit 1
    fi
fi

# Confirm device is not the system disk
if [[ "$DEVICE" == "$(lsblk -no pkname /boot | head -n1)" ]]; then
    echo "CRITICAL ERROR: $DEVICE is your system disk (where /boot is located)!"
    echo "I will not let you destroy your OS. Aborting."
    exit 1
fi

MCS_VERSION=$(cat VERSION)
IMAGE="artifacts/mcs-${MCS_VERSION}.iso"

if [[ ! -f "$IMAGE" ]]; then
    echo "Error: Image $IMAGE not found. Did you run ./build first?"
    exit 1
fi

echo "---------------------------------------------------"
echo "  Migasfree Clone System - USB Deployment"
echo "---------------------------------------------------"
echo "  SOURCE IMAGE: $IMAGE"
echo "  TARGET DEVICE: $DEVICE"
echo "---------------------------------------------------"
lsblk "$DEVICE"
echo "---------------------------------------------------"
echo "WARNING: ALL DATA ON $DEVICE WILL BE PERMANENTLY ERASED!"
read -p "Are you absolutely sure you want to proceed? (y/N): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 1
fi

# Unmount all partitions of the device to avoid "busy" errors
echo "[+] Unmounting partitions on $DEVICE..."
# We use -nlo to avoid headers and -r to get simple paths
for part in $(lsblk -nlo NAME "$DEVICE" 2>/dev/null | tail -n +2); do
    PART_PATH="/dev/$part"
    if mount | grep -q "$PART_PATH"; then
        echo "    Unmounting $PART_PATH..."
        umount -l "$PART_PATH" 2>/dev/null || true
    fi
done

echo "[+] Writing image to $DEVICE (using dd)..."
echo "    (Using direct sync for real-time progress. This may take a few minutes.)"
dd if="$IMAGE" of="$DEVICE" bs=4M status=progress conv=fsync oflag=dsync

if [[ $? -eq 0 ]]; then
    echo "[+] Finalizing (syncing buffers)..."
    sync
    echo "[✔] Success! You can now boot from $DEVICE."
else
    echo "[✘] Error: Failed to write image."
    exit 1
fi
