# Architecture & Technical Deep Dive

The **Migasfree Clone System (MCS)** is designed as a specialized live environment for system deployment. This document explains the internal structure, partitioning schemes, and the image generation workflow.

## 💾 Partitioning Scheme

The MCS bootable image uses a GPT partition table with support for both legacy BIOS and modern UEFI booting.

### MCS Image Structure (The "USB" Image)

When the `build` script runs, it creates a 3GB (default) image with the following partitions:

| Partition | Label | Filesystem | Size | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `MCS_EFI` | vfat | 100MB | EFI System Partition (ESP) for UEFI boot. |
| 2 | - | - | 1MB | BIOS Boot Partition for GRUB on GPT/BIOS. |
| 3 | `MCS_ROOT` | ext4 | 2GB | The Alpine Linux root filesystem. |
| 4 | `MCS_DATA` | ext4 | ~1GB | Data partition for images and configurations. |

### Target System Scheme (Defined in `functions`)

The `functions` library defines a default layout for target systems (clones):

- **EFI**: 512MB (vfat)
- **BIOS**: 1MB
- **SWAP**: 4GB
- **SYSTEM**: 20GB (ext4)
- **HOME**: Variable (ext4)

## 🛠️ Build Workflow

The build process is containerized to ensure all dependencies (`parted`, `grub`, `rsync`) are consistent.

1. **Host Orchestration (`/build`)**: 
   - Prepares a sparse file.
   - Sets up a loop device on the host.
   - Triggers the Docker container with privileged access.

2. **Image Construction (`/defaults/usr/bin/makeimg`)**:
   - Downloads the Alpine MiniRootFS.
   - Installs necessary packages via `apk`.
   - Injects the `/overlay` files.
   - Configures the bootloader (GRUB) for both targets.
   - Finalizes by renaming the raw `.img` file to a bootable `.iso` format for broader compatibility with flashing tools.

## 🔄 Cloning Mechanism

MCS uses a file-level cloning approach rather than block-level (dd) for the main partitions (`SYSTEM`, `HOME`). This allows:

- **Resizing**: Images can be deployed to disks of different sizes.
- **Speed**: Only used blocks are transferred via `rsync`.
- **Flexibility**: Changes can be made to the filesystem type during deployment.

### Sequence Diagram: Cloning Process

```mermaid
sequenceDiagram
    participant U as User (TUI)
    participant M as menu.sh
    participant F as functions
    participant S as Source Image (QCOW2)
    participant T as Target Disk

    U->>M: Select "Clone"
    M->>F: connect_HD(Source)
    F->>S: mount via qemu-nbd
    M->>F: make_partitions(Target)
    F->>T: create GPT & Partitions
    M->>F: rsync(Source, Target)
    F->>T: Transfer files
    M->>F: rescue(Target)
    F->>T: Install GRUB & Update Initramfs
    M->>U: Show "Success"
```

## 🌐 Networking

MCS is configured to use DHCP on all interfaces by default. Upon boot, it attempts to:
1. Initialize networking.
2. Download the CA certificate from the configured `SERVER_URL`.
3. Update system certificates to allow secure image downloads via HTTPS.
