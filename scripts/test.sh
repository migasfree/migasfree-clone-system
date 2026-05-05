#!/bin/bash

# Migasfree Clone System - Testing Script
# This script prepares a testing image and launches QEMU.

ARTIFACTSDIR="./artifacts"
MCS_VERSION=$(cat VERSION)
SOURCE_IMG="${ARTIFACTSDIR}/mcs-${MCS_VERSION}.iso"

# Default values
TEST_RAM="2G"
TEST_DISK_NAME="mcs-testing.iso"
TEST_DISK_SIZE="8G"
TEST_UEFI="false"
OVMF_PATH="/usr/share/ovmf/OVMF.fd"

# Load configuration if exists
if [ -f "mcs.conf" ]; then
    source "mcs.conf"
fi

# Help function
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -m <ram>       Memory for the VM (default: $TEST_RAM)"
    echo "  -s <size>      Disk size for testing (default: $TEST_DISK_SIZE)"
    echo "  -u             Enable UEFI mode (default: $TEST_UEFI)"
    echo "  -n <name>      Name for the testing image (default: $TEST_DISK_NAME)"
    echo "  -d <device>    Use a physical device (e.g. /dev/sda) instead of an image"
    echo "  -h             Show this help"
    exit 1
}

# Parse command line arguments
while getopts "m:s:un:d:h" opt; do
    case ${opt} in
        m ) TEST_RAM=$OPTARG ;;
        s ) TEST_DISK_SIZE=$OPTARG ;;
        u ) TEST_UEFI="true" ;;
        n ) TEST_DISK_NAME=$OPTARG ;;
        d ) PHYSICAL_DEV=$OPTARG ;;
        h ) usage ;;
        \? ) usage ;;
    esac
done

if [ -n "$PHYSICAL_DEV" ]; then
    TEST_IMG="$PHYSICAL_DEV"
    if [ ! -b "$TEST_IMG" ]; then
        echo "Error: Physical device $TEST_IMG not found or not a block device."
        exit 1
    fi
    echo "[+] Using physical device: $TEST_IMG"
else
    TEST_IMG="${ARTIFACTSDIR}/${TEST_DISK_NAME}"

    # 1. Check if source image exists
    if [ ! -f "$SOURCE_IMG" ]; then
        echo "Error: Source image $SOURCE_IMG not found."
        echo "Please run ./build first."
        exit 1
    fi

    # 2. Prepare testing image (copy and resize)
    echo "[+] Preparing testing image: $TEST_IMG (${TEST_DISK_SIZE})..."
    cp "$SOURCE_IMG" "$TEST_IMG"
    qemu-img resize "$TEST_IMG" "$TEST_DISK_SIZE"
fi

# 3. Handle Target Disk
TARGET_DRIVE=""
if [ -n "$TEST_TARGET_DISK" ]; then
    TARGET_PATH="${ARTIFACTSDIR}/${TEST_TARGET_DISK}"
    
    # Determine format
    TARGET_FORMAT="raw"
    [[ "$TEST_TARGET_DISK" == *.qcow2 ]] && TARGET_FORMAT="qcow2"

    if [ ! -f "$TARGET_PATH" ]; then
        echo "[+] Creating target disk: $TARGET_PATH ($TEST_TARGET_SIZE) as $TARGET_FORMAT..."
        qemu-img create -f "$TARGET_FORMAT" "$TARGET_PATH" "$TEST_TARGET_SIZE"
    fi
    
    TARGET_DRIVE="-drive file=$TARGET_PATH,format=$TARGET_FORMAT,index=1,media=disk"
fi

# 4. Build QEMU command
DRIVE_OPTS="format=raw,index=0,media=disk"
[ -n "$PHYSICAL_DEV" ] && DRIVE_OPTS="${DRIVE_OPTS},cache=none"

QEMU_CMD="sudo qemu-system-x86_64 \
    -m $TEST_RAM \
    -enable-kvm \
    -cpu host \
    -net nic,model=virtio -net user \
    -drive file=$TEST_IMG,$DRIVE_OPTS \
    $TARGET_DRIVE \
    -monitor unix:/tmp/qemu-monitor.sock,server,nowait"

if [ "$TEST_UEFI" = "true" ]; then
    if [ -f "$OVMF_PATH" ]; then
        echo "[+] Enabling UEFI mode (using $OVMF_PATH)..."
        QEMU_CMD="$QEMU_CMD -bios $OVMF_PATH"
    else
        echo "Error: OVMF firmware not found at $OVMF_PATH."
        echo "Please check your mcs.conf or install the ovmf package."
        exit 1
    fi
fi

# 5. Launch QEMU
echo "[+] Launching QEMU..."
echo "    RAM: $TEST_RAM"
echo "    UEFI: $TEST_UEFI"
echo "    Target: ${TEST_TARGET_DISK:-none}"
eval "$QEMU_CMD"
