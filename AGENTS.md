# 🤖 AI Agent Context (MCS)

This document provides essential technical context for AI agents working on the **Migasfree Clone System (MCS)**.

## 🎯 Project Purpose

MCS is a lightweight, Alpine Linux-based imaging and deployment utility. It is designed to clone system images to local disks via Network (HTTP streaming) or Local USB.

## 🏗️ Core Architecture

- **Base OS**: Minimal Alpine Linux.
- **Build System**: Docker-based multi-stage build.
- **TUI**: Shell-based (bash) using `dialog`.
- **Cloning Engine**: Block-level `dd` and `wget | dd` streaming for high performance.
- **Persistence**: Uses a data partition (`MCS_DATA`) for storing images and configuration.

## 📁 Key File Map

- `/scripts/build.sh`: Orchestrates the image creation on the host.
- `/scripts/test.sh`: QEMU launch script for verifying the build.
- `/scripts/test-boot.sh`: QEMU script to verify if the cloned disk is bootable.
- `/scripts/makeusb.sh`: Script to create the physical bootable USB drive.
- `/defaults/overlay/usr/share/mcs/menu.sh`: The main TUI logic and entry point.
- `/defaults/overlay/usr/share/mcs/functions`: Core library for disk management, partitioning, and cloning.
- `/defaults/apks/packages`: List of Alpine packages included in the image.
- `/mcs.conf`: Central configuration for build and test parameters.

## 📀 Project Data Structure

MCS has transitioned from single `.qcow2` files to **Project Directories**.

- **Server Path**: `http://<SERVER_URL>/pool/mcs/<PROJECT_NAME>/`
- **Local Path**: `/mcsdata/pool/mcs/<PROJECT_NAME>/`
- **Required Files per Project**:
  - `SYSTEM.raw`: Root filesystem partition.
  - `DATA.raw`: Data or secondary partition (used as fallback for HOME).

## 🚀 Technical Workflows

### Cloning Logic

- **Network Clone**: Streams `SYSTEM.raw` and `DATA.raw` directly from the server to target partitions using `wget -O - | dd`. Known as "Turbo Clone".
- **Local Clone**: Uses `dd` to copy `.raw` files from the USB data partition to target partitions.

### Partitioning

MCS expects a specific partition scheme on the target disk (standard Migasfree/Vitalinux layout):

- EFI (vfat)
- BIOS/BOOT (ext4)
- SYSTEM (ext4)
- DATA/HOME (ext4)

## 🛠️ Development & Testing

- **Building**: Use `make build`. It creates `artifacts/mcs-<version>.iso`.
- **Testing**: Use `make test`. It simulates a real environment with a target disk `artifacts/target-hd.qcow2`.
- **Verification**: After cloning inside the test VM, use `make test-boot` to verify the target disk's bootloader.

## ⚠️ Critical Constraints

- **Destructive**: `clone_HD` wipes the target disk's partition table.
- **Root**: Most operations require `sudo` due to disk/loop device manipulation.
- **Minimalism**: Keep the overlay (`/defaults/overlay`) as small as possible to minimize ISO size.
