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

### User Preservation

| Function | Arguments | Description |
| :--- | :--- | :--- |
| `backup_local_users` | `device` | Mounts the target SYSTEM partition and copies `/etc/passwd`, `/etc/shadow`, `/etc/group`, and `/etc/gshadow` to `/tmp/mcs_user_backup/`. |
| `restore_local_users` | `mount_point, device?` | Merges backed-up local users (UID ≥ 1000, excluding `nobody`) into the new system. Handles UID/GID collision cleanup, group creation, and supplemental group membership restoration. Unconditionally protects the target's UID 1000 administrator user, resolving any missing home directories on the preserved HOME partition by creating and initializing them from `/etc/skel`. |
| `add_user_to_group` | `group_file, group, user` | Appends a user to a group's member list in the given group file, avoiding duplicates. |
| `check_local_users_safety` | `device` | Mounts the target SYSTEM partition read-only and checks if UID 1000 is occupied by a standard (non-admin) user. Returns `1` and shows an error dialog if a conflict is found. Called from the TUI before cloning when Preserve HOME is selected. |

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
4. **User Account Preservation** (when `PRESERVE_HOME` is active):
   - Before cloning, `backup_local_users` saves the target disk's user databases.
   - After cloning, `restore_local_users` merges backed-up standard users into the fresh system image.

## 🔐 Centralized Admin Protection (`MIGASFREE-ADMIN`)

To ensure that the organization's central administrator (UID 1000) is never lost, broken, or mixed with normal users during cloning:

### 1. Safety Check (Before Cloning)

Before starting, MCS checks the existing disk:

- **If UID 1000 is a normal user (not an administrator)**: The installation stops immediately for safety to avoid destroying user data.
- **If UID 1000 is a Migasfree administrator or empty**: The installation continues safely.

### 2. Administrator Restoration (After Cloning)

When cloning finishes and user accounts are restored:

- **The New Admin Wins**: The administrator user that comes with the new MCI (e.g., `senior`) is installed on the disk. The old backup administrator is skipped.
- **Clean Old Admin Sweep**: If the old administrator has a different name (e.g., `admin` instead of `senior`), all its traces (user account, groups, and the `/home/admin` folder) are **completely deleted** from the disk to avoid clutter or login errors.
- **Fresh Start for the New Admin**: If the new administrator's folder (e.g., `/home/senior`) does not exist on the preserved `/home` partition, MCS automatically creates it, copies clean default settings (from `/etc/skel`), and sets correct permissions (`1000:1000`) so the graphical desktop (X11) starts perfectly.
- **Normal Users are Preserved**: All other standard local users are merged back normally without modifications.

## ⚠️ Important Notes

- **RAW Partition Streaming**: The library is optimized for projects containing `SYSTEM.raw` and `HOME.raw`.
- **Root Required**: Almost all functions require root privileges.
- **Safety**: By default, `clone_HD` is destructive; it will wipe the partition table unless `PRESERVE_HOME` is validated and requested.
- **Admin Convention**: All MCI images must ship with UID 1000 as the admin user, tagged `MIGASFREE-ADMIN` in the GECOS field.
