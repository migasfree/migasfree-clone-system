#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (sudo)."
   exit 1
fi

# Load configuration
if [ -f "mcs.conf" ]; then
    source "mcs.conf"
else
    echo "Warning: mcs.conf not found, using defaults."
    MCS_SIZE_MB="3072"
    SERVER_URL="inv.org"
    KEYMAP="es"
fi

MCS_VERSION=$(cat VERSION)
ARTIFACTSDIR=./artifacts
IMG=mcs-${MCS_VERSION}.img
SIZE_MB=$MCS_SIZE_MB
SERVER=$SERVER_URL
KEYMAP=$KEYMAP

docker build -t migasfree/mcs:$MCS_VERSION .

if [ $? = 0 ]
then
    mkdir -p ${ARTIFACTSDIR}

    echo "[+] Creando ${ARTIFACTSDIR}/${IMG} de ${SIZE_MB}..."

    dd if=/dev/zero of=${ARTIFACTSDIR}/${IMG} bs=1M count=$SIZE_MB

    echo "[+] Partitions..."
    parted --script ${ARTIFACTSDIR}/${IMG} \
      mklabel gpt \
      mkpart ESP fat32 1MiB 100MiB \
      set 1 esp on \
      mkpart BIOSBOOT 100MiB 101MiB \
      set 2 bios_grub on \
      mkpart ROOT ext4 101MiB 2101MiB \
      mkpart DATA ext4 2101MiB 2201MiB
    partprobe ${LOOPDEV}
    sleep 1
    parted "${ARTIFACTSDIR}/${IMG}" print

    echo "[+] Loop device..."
    LOOPDEV=$(losetup -f)
    losetup -P "$LOOPDEV" "${ARTIFACTSDIR}/$IMG"

    echo "[+] Formateando particiones..."
    mkfs.vfat -n MCS_EFI "${LOOPDEV}p1"
    mkfs.ext4 -L MCS_ROOT "${LOOPDEV}p3"
    mkfs.ext4 -L MCS_DATA "${LOOPDEV}p4"

    docker run -ti --rm \
        --privileged \
        --device ${LOOPDEV} \
        -e MCS_VERSION=${MCS_VERSION} \
        -e LOOPDEV=${LOOPDEV} \
        -e IMG=$IMG \
        -e SERVER=${SERVER} \
        -e SERVER_IP="${SERVER_IP}" \
        -e KEYMAP=${KEYMAP} \
        -v ${ARTIFACTSDIR}:/artifacts \
        migasfree/mcs:$MCS_VERSION makeimg

    losetup -D "$LOOPDEV"

fi