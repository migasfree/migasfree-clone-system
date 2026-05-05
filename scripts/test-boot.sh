#!/bin/bash

# Migasfree Clone System - Boot Testing Script
# This script launches QEMU using ONLY the target disk to verify it's bootable.

ARTIFACTSDIR="./artifacts"
TEST_RAM="2G"
TEST_UEFI="false"
OVMF_PATH="/usr/share/ovmf/OVMF.fd"
TEST_TARGET_DISK="target-hd.qcow2"

# Load configuration if exists
if [ -f "mcs.conf" ]; then
    source "mcs.conf"
fi

TARGET_PATH="${ARTIFACTSDIR}/${TEST_TARGET_DISK}"

if [ ! -f "$TARGET_PATH" ]; then
    echo "Error: Target disk $TARGET_PATH not found."
    echo "Please run a cloning test first using ./test."
    exit 1
fi

# Determine format
TARGET_FORMAT="raw"
[[ "$TEST_TARGET_DISK" == *.qcow2 ]] && TARGET_FORMAT="qcow2"

echo "[+] Booting from target disk: $TARGET_PATH..."
echo "    RAM: $TEST_RAM"
echo "    UEFI: $TEST_UEFI"

QEMU_CMD="sudo qemu-system-x86_64 \
    -m $TEST_RAM \
    -enable-kvm \
    -cpu host \
    -drive file=$TARGET_PATH,format=$TARGET_FORMAT \
    -monitor unix:/tmp/qemu-monitor.sock,server,nowait"

if [ "$TEST_UEFI" = "true" ]; then
    if [ -f "$OVMF_PATH" ]; then
        echo "[+] Enabling UEFI mode..."
        QEMU_CMD="$QEMU_CMD -bios $OVMF_PATH"
    fi
fi

eval "$QEMU_CMD"
