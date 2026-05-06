# Physical USB Deployment Guide

This guide explains how to create a bootable **Migasfree Clone System (MCS)** USB drive. The process involves writing the system image (ISO) to a physical drive using a block-level copy.

> [!CAUTION]
> This process is destructive. All data on the target USB drive will be permanently erased. Double-check your device identifier before proceeding.

## Prerequisites

- A physical USB drive (at least 4GB, though 16GB+ is recommended for storing images).
- Root privileges (`sudo`) on the build machine.

---

## Recommended Method: Interactive Script

The safest and easiest way to create your bootable media is by using the provided interactive script. It handles device detection, unmounting, and safety confirmations automatically.

### 1. Launch the Writer

Run the following command from the root of the repository:

```bash
make usb
```

### 2. Follow the Interactive Menu

The script will scan your system for USB devices and present a numbered list:

1. **Detection**: Select the number corresponding to your USB drive.
2. **Safety Check**: The script verifies that the selected device is a real USB drive and not your system disk.
3. **Confirmation**: A final warning will be displayed. Type `y` to start the writing process.

The script uses `dd` with synchronization flags to ensure that the data is physically written to the disk before completion.

---

## First Boot and Persistence

Once the writing process is finished, your USB drive is ready to use.

### Automatic Partition Expansion

On the **very first boot**, MCS automatically expands the data partition (`MCS_DATA`) to occupy **all remaining free space** on the USB drive. This ensures you have the maximum storage available for system images and configuration files.

No manual intervention is required during this process.

---

## Alternatives: Graphical Tools

If you prefer using a graphical interface instead of the terminal, the MCS ISO is compatible with standard flashing utilities:

1. [BalenaEtcher](https://www.balena.io/etcher/): The most recommended cross-platform tool. Simple 3-step interface.
2. [Ventoy](https://www.ventoy.net/): You can copy the MCS `.iso` file directly to a Ventoy-prepared drive.

> [!NOTE]
> While Ventoy is convenient, using the **Recommended Method** (direct `dd`) ensures the most reliable performance for the persistent data partition.
