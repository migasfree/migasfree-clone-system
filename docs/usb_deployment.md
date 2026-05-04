# How-to: Deployment to a Physical USB Drive

This guide explains how to transfer the **Migasfree Clone System (MCS)** image from your computer to a physical USB drive.

> [!CAUTION]
> This process is destructive. All data on the target USB drive will be permanently erased. Double-check your device identifier before proceeding.

## 📋 Prerequisites

- A physical USB drive (at least 4GB, though 16GB+ is recommended for storing images).
- Root privileges (`sudo`).

---

## 🚀 Recommended Method: Using the `makeusb` script

We provide a built-in script that handles the writing process safely, including a confirmation prompt to prevent accidental data loss.

### 1. Identify your USB Drive
Connect your USB drive and identify its device path (e.g., `/dev/sdb`).

```bash
lsblk
```

### 2. Run the deployment script
Pass the device path as an argument to the script:

```bash
sudo ./makeusb /dev/sdX
```

The script will:
- Verify that the image exists.
- Display information about the target device.
- Ask for your confirmation.
- Write the bootable image to the USB drive using `dd`.

---

## 🛠️ Manual Method (Advanced)

If you prefer to do it manually without the script, you can use the `dd` utility directly. The build process now produces a raw, bootable image with an `.iso` extension.

### Write with `dd`
```bash
sudo dd if=artifacts/mcs-1.1.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

### Explanation of parameters:
- **`if=...`**: Input file (the bootable `.iso` image).
- **`of=/dev/sdX`**: Output file (the physical USB device).
- **`bs=4M`**: Use 4MB block size for faster writing.
- **`status=progress`**: Shows a progress bar.
- **`conv=fsync`**: Ensures all data is physically written to the disk before finishing.

---

## 🚀 Step 4: First Boot

Once the process is complete, you can boot any computer from this USB drive.

### Automatic Expansion
On the **very first boot**, MCS will detect that it is running for the first time and will automatically:
1. Resize the `MCS_DATA` partition to occupy the remaining space on your USB drive.
2. Prepare the environment for storing system images.

No manual intervention is required for this expansion.

---

## 🛠️ Alternative: Using Etcher or Ventoy

If you prefer a graphical tool:
1. **BalenaEtcher**: You can select the `.iso` file and flash it easily.
2. **Ventoy**: MCS is a standard Linux image. You can copy the `.iso` to a Ventoy drive, although the standard `dd` method is the most reliable for MCS.
