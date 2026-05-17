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
| `check_home_viability` | `device` | Verifies if the target disk has a compatible partition layout to preserve user data. |

### Image Manipulation

| Function | Arguments | Description |
| :--- | :--- | :--- |
| `clone_HD` | `source, target, preserve_home?` | Clones a source project (directory or URL) to a target block device. Orchestrates the full cloning workflow via `resolve_partition_target`, `clone_partition_http` and `clone_partition_local`. |
| `resolve_partition_target` | `target, name, number` | Resolves the target partition device by label first, falling back to partition number. |
| `clone_partition_http` | `url, device, name` | Streams a single `.raw` partition via HTTP `wget \| pv \| dd` (Turbo Clone) and verifies integrity. |
| `clone_partition_local` | `source_dir, device, name` | Copies a single `.raw` partition from a local directory via `pv \| dd`, verifies integrity and expands the filesystem. |
| `expand_filesystem` | `device, name` | Expands an `ext*` filesystem to fill its partition using `e2fsck` and `resize2fs`. Automatically called after cloning. |
| `verify_partition_checksum` | `device, partition_name` | Verifies the SHA-256 checksum of a written partition against the `checksums.sha256` file from the project. Reads the expected size from the checksums file. |
| `rescue` | `device` | Reinstalls GRUB and regenerates `fstab` and `initramfs` on a target system. |

## 🛠️ Usage Example

To manually clone a project from a shell inside MCS:

```bash
source /usr/share/mcs/functions

# Clone a local project to the first SATA disk
clone_HD /mcsdata/pool/mci/inv.org_lnx-1 /dev/sda

# Clone a remote project directly via network streaming
clone_HD http://your-server.org/pool/mci/inv.org_lnx-1/ /dev/sda
```

## 🛡️ Preserve HOME Logic

The "Preserve HOME" feature allows deploying a new system image without wiping the user's data partition.

### Viability Check (`check_home_viability`)

For a developer, a "Compatible Layout" is strictly defined by the metadata of the target disk compared to the current project's `partition.yml`. MCS uses `sfdisk -J` to inspect the target disk without mounting it:

1. **GPT/MBR Name Matching**: The function scans for partitions where the `name` attribute (GPT label) exactly matches `SYSTEM` and `HOME`.
2. **Strict Node Alignment**: It extracts the partition number from the device node (e.g., `sda3` -> `3`). This number MUST match the `number` defined for that partition in the project's YAML. This ensures that the cloned image's expectations about partition order are met.
3. **Partition Capacity**: It converts the current partition's sector count to MB and ensures it is greater than or equal to the `size` defined in the project scheme.
4. **FSTYPE agnostic**: The check does not care about the *content* of the partitions at this stage, only their structural definition.

### Cloning Workflow with Preservation

When `PRESERVE_HOME` is active:

1. **Bypass Disk Wipe**: The standard `make_HD` (which calls `make_partitions` and `make_file_systems`) is completely skipped.
2. **Bootloader & Boot Partitions**:
   - Even if `HOME` is preserved, the **boot partitions** (EFI or BIOS/BOOT) are handled by the `rescue` function.
   - If the project includes a `SYSTEM.raw` image that contains the `/boot` directory, it is written to the `SYSTEM` partition.
3. **Rescue Operation**:
   - **FSTAB**: A new `/etc/fstab` is generated on-the-fly using `PARTUUID`s to ensure the system boots correctly regardless of device name changes (`sda` vs `nvme`).
   - **GRUB (BIOS)**: Reinstalled using the `--target=i386-pc` and `--force` flags.
   - **GRUB (UEFI)**: If an `EFI` partition is detected by label, it is mounted and the EFI binaries are re-synchronized via `grub-install --target=x86_64-efi`.

## ⚠️ Important Notes

- **RAW Partition Streaming**: The library is optimized for projects containing `SYSTEM.raw` and `HOME.raw`.
- **Root Required**: Almost all functions require root privileges.
- **Safety**: By default, `clone_HD` is destructive; it will wipe the partition table unless `PRESERVE_HOME` is validated and requested.
