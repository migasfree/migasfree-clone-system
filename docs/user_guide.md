# 📘 End-User Guide: Deploying with MCS

This guide explains how to use the **Migasfree Clone System (MCS)** to deploy system images to your computer fleet.

## 1. Getting the ISO

Download the latest `mcs-<version>.iso` from your organization's Migasfree server. It is usually located at:
`https://<YOUR_SERVER_URL>/pool/mcs/`

This ISO is already pre-configured to point to your server, so you don't need to change any settings manually.

## 2. Creating the Bootable USB

You need to write the ISO to a USB drive (minimum 4GB, 32GB+ recommended if you plan to store local images).

### Using Linux (Command Line)

Identify your USB device (e.g., `/dev/sdc`) and run:

```bash
sudo dd if=mcs-1.1.iso of=/dev/sdX bs=4M status=progress
```

### Using Windows/macOS (GUI)

- **BalenaEtcher**: Simple and cross-platform. Just select the ISO, the drive, and click "Flash!".
- **Rufus (Windows only)**: Select the ISO and the drive. **IMPORTANT**: When prompted, choose **"Write in DD Image mode"**.

---

## 3. Booting MCS

1. Insert the USB into the target computer.
2. Turn on the computer and press the boot menu key (usually F12, F11, F10, or ESC).
3. Select the USB drive (supports both **BIOS** and **UEFI**).

---

## 4. Understanding the Menu

Once MCS boots, you will see the following options:

### 🚀 Network Clone

The fastest method if you have a good internet connection (Gigabit network recommended).

- It streams the system project directly from the server to your hard drive.
- No local storage on the USB is required.

### 💾 Local Clone

Use this if you are in a location with slow or no internet.

- It clones the project from the USB's internal data partition to the computer.
- You must have downloaded the project previously (see below).

### 📁 Local Images

Management tools for your USB drive:

- **List**: See which projects are already on your USB.
- **Download**: Fetch a new project from the server and save it to the USB for future "Local Clones".
- **Delete**: Remove projects to free up space.

### ⚙️ Settings

- Change the **Server URL** if you need to point to a different repository.
- Change the **Server IP** (DNS Override): Enter the static IP of your server if DNS resolution is not available in your current network. This will force the system to resolve the domain to that IP.
- Change the **Keyboard Layout** (default is usually Spanish).

---

## 5. Troubleshooting

- **Network Error**: Ensure the ethernet cable is plugged in. MCS attempts to get an IP via DHCP automatically.
- **Disk Not Found**: Ensure the target computer's SATA mode is set to AHCI in the BIOS.
