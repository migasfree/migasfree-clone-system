# MCS Functions Library Reference

The `functions` script (located at `/usr/share/mcs/functions` in the booted system) is the core library of the Migasfree Clone System. It provides advanced disk management and image manipulation utilities.

## 📦 Core Functions

### Disk Connectivity

| Function | Arguments | Description |
| :--- | :--- | :--- |
| `connect_HD` | `target` | Connects a file (IMG), directory, or block device. Returns the device/directory path. |
| `disconnect_HD` | `device` | Safely disconnects an NBD device (if used) and syncs buffers. |

### Partitioning & Labels

| Function | Arguments | Description |
| :--- | :--- | :--- |
| `make_partitions` | `device` | Creates a new GPT partition table and the standard MCS partition set. |
| `part_by_label` | `label` | Returns the device path (e.g., `/dev/sda1`) of a partition with a specific filesystem label. |
| `disk_by_label` | `label` | Returns the parent disk device of a partition with a specific label. |
| `uuid_by_name` | `device, name` | Returns the PARTUUID of a partition by its name (SYSTEM, EFI, etc.). |

### Image Manipulation

| Function | Arguments | Description |
| :--- | :--- | :--- |
| `clone_HD` | `source, target` | Clones a source project (directory or URL) to a target block device. Uses high-speed `dd` or `wget \| dd` streaming for RAW files. |
| `verify_partition_checksum` | `device, partition_name` | Verifies the SHA-256 checksum of a written partition against the `checksums.sha256` file from the project. Reads the expected size from the checksums file. |
| `rescue` | `device` | Reinstalls GRUB and regenerates `fstab` and `initramfs` on a target system. |

## 🛠️ Usage Example

To manually clone a project from a shell inside MCS:

```bash
source /usr/share/mcs/functions

# Clone a local project to the first SATA disk
clone_HD /mcsdata/pool/mcs/inv.org_lnx-1 /dev/sda

# Clone a remote project directly via network streaming
clone_HD http://your-server.org/pool/mcs/inv.org_lnx-1/ /dev/sda
```

## ⚠️ Important Notes

- **RAW Partition Streaming**: The library is optimized for projects containing `SYSTEM.raw` and `HOME.raw`.
- **Root Required**: Almost all functions require root privileges.
- **Safety**: The `clone_HD` function is destructive; it will wipe the partition table of the target device.
