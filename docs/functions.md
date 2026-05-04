# MCS Functions Library Reference

The `functions` script (located at `/usr/share/mcs/functions` in the booted system) is the core library of the Migasfree Clone System. It provides advanced disk management and image manipulation utilities.

## 📦 Core Functions

### Disk Connectivity

| Function | Arguments | Description |
| :--- | :--- | :--- |
| `connect_HD` | `target` | Connects a file (QCOW2/IMG) or block device. Uses `qemu-nbd` for files. Returns the device path. |
| `disconnect_HD` | `device` | Safely disconnects an NBD device and syncs buffers. |

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
| `shrink_part` | `device, id` | Minimizes the size of an ext4 partition to its content size. |
| `clone_HD` | `source, target` | Clones a source QCOW2 image to a target block device. Handles partitioning and file transfer. |
| `rescue` | `device` | Reinstalls GRUB and regenerates `fstab` and `initramfs` on a target system. |

## 🛠️ Usage Example

To manually clone an image from a shell inside MCS:

```bash
source /usr/share/mcs/functions

# Clone an image to the first SATA disk
clone_HD /mcsdata/images/my_image.qcow2 /dev/sda
```

## ⚠️ Important Notes

- **NBD Management**: The library uses `/dev/nbd0` through `/dev/nbd15`. Use `free_nbd` to clear all connections if devices get stuck.
- **Root Required**: Almost all functions require root privileges and specific kernel modules (`nbd`).
- **Safety**: The `clone_HD` function is destructive; it will wipe the partition table of the target device.
