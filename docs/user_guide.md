# 📘 End-User Guide: Deploying with MCS

This guide explains how to use the **Migasfree Clone System (MCS)** to deploy system images to your computer fleet.

## 1. Getting the ISO

Download the latest `mcs-<version>.iso` from your organization's Migasfree server at: `https://<YOUR_SERVER_URL>/pool/mcs/`

This ISO is already pre-configured to point to your server, so you don't need to change any settings manually.

## 2. Creating the Bootable USB

To create the bootable media, we recommend using a simple graphical tool. You will need a USB drive of at least 4GB (32GB+ recommended if you want to store images locally).

### Recommended: BalenaEtcher (Windows, macOS, Linux)

This is the easiest and safest method.

1. Download **BalenaEtcher** from [balena.io/etcher](https://www.balena.io/etcher/).
2. Insert your USB drive into your computer.
3. Open the program and follow these 3 steps:
   - **Flash from file**: Select the `mcs-<version>.iso` you downloaded.
   - **Select target**: Choose your USB drive.
   - **Flash!**: Wait for the process to finish and verify.

### Alternative for Windows: Rufus

1. Download **Rufus** from [rufus.ie](https://rufus.ie/).
2. Select your USB drive in the **Device** dropdown.
3. Click **SELECT** and choose the MCS ISO file.
4. Click **START**.
   - *Note: If prompted about "ISOHybrid", select **Write in DD Image mode**.*

> [!TIP]
> **Advanced Users**: You can still use `dd` on Linux:
> `sudo dd if=mcs-<version>.iso of=/dev/sdX bs=4M status=progress`
---

## 3. Booting MCS

1. Insert the USB into the target computer.
2. Turn on the computer and press the boot menu key (usually F12, F11, F10, or ESC).
3. Select the USB drive (supports both **BIOS** and **UEFI**).

---

## 4. Understanding the Menu

Once MCS boots, you will see the following options:

### 🚀 Network Clone

Streams the system project directly from the server to your target disk.

- **Speed**: Depends on your network bandwidth and server response. In a **Gigabit network**, this is often faster than using an older USB 2.0 drive.
- **Advantage**: No local storage on the USB is required; you always deploy the latest version available on the server.

### 💾 Local Clone

Clones the project from the USB's internal data partition to the computer.

- **Speed**: Depends on the **read speed of your USB drive**. If you use a high-speed **USB 3.0/3.1** drive, this method can be faster than the network.
- **Advantage**: Works without an active network connection. Ideal for isolated locations or when the server is under heavy load.

### 📁 Local Images

Management tools for your USB drive:

- **List**: See which projects are already on your USB.
- **Download**: Fetch a new project from the server and save it to the USB for future "Local Clones".
- **Delete**: Remove projects to free up space.

### ⚙️ Settings

- Change the **Server URL** if you need to point to a different repository.
- Change the **Server IP** (DNS Override): Enter the static IP of your server if DNS resolution is not available in your current network. This will force the system to resolve the domain to that IP.
- Change the **Keyboard Layout** (default is usually Spanish).
- **Verify Integrity**: Enable or disable SHA-256 checksum verification after cloning. Disabling this saves time but reduces security/reliability on unstable networks.

---

## 5. Troubleshooting

- **Network Error**: Ensure the ethernet cable is plugged in. MCS attempts to get an IP via DHCP automatically.
- **Disk Not Found**: Ensure the target computer's SATA mode is set to AHCI in the BIOS.
