#!/bin/bash
set -o pipefail

# Migasfree Clone System - Boot Testing Script
# This script launches QEMU using ONLY the target disk to verify it's bootable.

# Default values (will be overridden by mcs.conf)
ARTIFACTSDIR="./artifacts"

# Load configuration
if [ -f "mcs.conf" ]; then
    source "mcs.conf"
fi

# Fallbacks for mandatory testing variables if not in mcs.conf
TEST_RAM="${TEST_RAM:-2G}"
TEST_UEFI="${TEST_UEFI:-false}"
OVMF_PATH="${OVMF_PATH:-/usr/share/ovmf/OVMF.fd}"
TEST_TARGET_DISK="${TEST_TARGET_DISK:-target-hd.qcow2}"

# Parse command line arguments
while getopts "m:u" opt; do
    case ${opt} in
        m ) TEST_RAM=$OPTARG ;;
        u ) TEST_UEFI="true" ;;
    esac
done

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
    -net nic,model=virtio -net user \
    -device virtio-tablet-pci \
    -vga virtio \
    -drive file=$TARGET_PATH,format=$TARGET_FORMAT \
    ${TEST_UUID:+ -uuid $TEST_UUID} \
    -monitor unix:/tmp/qemu-monitor.sock,server,nowait"

if [ "$TEST_UEFI" = "true" ]; then
    if [ -f "$OVMF_PATH" ]; then
        echo "[+] Enabling UEFI mode..."
        QEMU_CMD="$QEMU_CMD -bios $OVMF_PATH"
    fi
fi

eval "$QEMU_CMD"
