# How-to: Testing with QEMU

This guide explains how to test the **Migasfree Clone System (MCS)** in a virtual environment using QEMU. This is the safest way to verify the build before writing it to a physical USB drive.

## 📋 Prerequisites

Before testing, ensure you have the necessary QEMU packages installed on your host system.

### For Debian / Ubuntu / Linux Mint

```bash
sudo apt update
sudo apt install qemu-system-x86 qemu-utils ovmf
```

### For Arch Linux

```bash
sudo pacman -S qemu-desktop ovmf
```

## 🚀 Recommended Method: Using the `qemu` target

We provide a built-in script that handles the creation of a temporary testing image and launches QEMU with the correct parameters.

### 1. Run the QEMU command

Simply run the make command from the root of the repository. You can pass additional arguments to the underlying script using the `ARGS` variable.

```bash
# Standard QEMU test
make qemu-clone

# With extra memory and UEFI
make qemu-clone ARGS="-m 4G -u"

# Test using a physical USB drive
make qemu-usb DRIVE=/dev/sda
```

**Available script options (via `ARGS="..."`):**

- `-m <ram>`: Memory for the VM (e.g., `4G`).
- `-s <size>`: Disk size for testing (e.g., `20G`).
- `-u`: Enable UEFI mode.
- `-n <name>`: Custom name for the testing image.
- `-d <device>`: Use a physical device (prefer `make qemu-usb` for this).

The script will:

- Copy the main MCS image to a temporary file (`artifacts/mcs-testing.iso`).
- Resize it to the specified size.
- Launch QEMU with KVM and `-cpu host` for maximum performance.

### 2. Configuration

You can customize the virtual machine behavior by editing **`mcs.conf`**:

```bash
# mcs.conf
TEST_RAM="2G"             # RAM for the VM
TEST_DISK_SIZE="8G"       # Size of the testing image
TEST_UEFI="true"          # Set to true to test UEFI boot
OVMF_PATH="/usr/share/ovmf/OVMF.fd"
TEST_UUID="71656d75-a1b2-c3d4-e5f6-7890abcdef01" # Fixed hardware UUID for Migasfree
```

### 3. Verifying the Clone (Boot Test)

Once you have performed a clone inside the VM, you can verify that the target disk is actually bootable using the **`make qemu-boot`** command:

```bash
make qemu-boot
```

This script will:

- Launch QEMU using ONLY the target disk (`target-hd.qcow2`).
- Verify that the GRUB bootloader and the operating system start correctly.

---

## Advanced Testing Scenarios

### Use a custom Target Disk

If you want to test how MCS behaves with a different target disk (size or format), you can set these variables in `mcs.conf`:

```bash
# Target disk name (e.g., target.qcow2 or target.raw)
TEST_TARGET_DISK="target-hd.qcow2"

# Target disk size
TEST_TARGET_SIZE="30G"
```

### Direct physical device access

If you want to test the cloning process directly on a physical disk (be careful!):

```bash
make qemu-usb DRIVE=/dev/sdX
```

This will launch QEMU using `/dev/sdX` as the primary boot drive and the virtual `target-hd.qcow2` as the second drive.

---

## Useful QEMU Shortcuts

- **Ctrl + Alt + G**: Release mouse grab.
- **Ctrl + Alt + 2**: Switch to QEMU monitor (type `quit` to exit).
- **Ctrl + Alt + 1**: Switch back to the guest display.
