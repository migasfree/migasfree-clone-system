# Server Setup & Image Management

This document explains how system images are stored on a centralized server, how to configure their partitioning, and the lifecycle of managing projects in the **Migasfree Clone System (MCS)**.

## 📂 The Image Pool

MCS is designed to pull system images from a centralized repository known as the **Image Pool**. This allows administrators to maintain a single source of truth for all deployable system images.

### Remote Server Structure

The remote server must serve files over HTTP/HTTPS. By default, MCS looks for projects in the following path:
`http://<SERVER_URL>/pool/mcs/`

**Requirements for the remote server:**

- **Format**: Images must be stored within **project directories**.
- **Directory Listing**: The web server must have directory listing enabled (Apache `mod_autoindex` or Nginx `autoindex on`). MCS parses the HTML index to identify available project directories.
- **Naming**: Use descriptive directory names (e.g., `inv.org_lnx-1`).

Each project directory must contain:

- `partition.yml` **(mandatory)**: Partition layout definition.
- `SYSTEM.raw`: The root filesystem partition image.
- `HOME.raw`: The data/user partition image.
- `checksums.sha256` **(optional)**: SHA-256 checksums for integrity verification.

---

## 📀 Disk Partitioning (`partition.yml`)

Every project in MCS **must** include a `partition.yml` file. This file defines the exact layout of the target disk, including partition sizes, filesystems, and mount points.

The system looks for this file in the following order:

1. **Network Clone**: `http://<SERVER_URL>/pool/mcs/<PROJECT_NAME>/partition.yml`
2. **Local USB Clone**: `/mcsdata/pool/mcs/<PROJECT_NAME>/partition.yml`

### Syntax

The file uses YAML format and must contain a `partitions` list.

```yaml
partitions:
  - number: 1
    name: "EFI"
    size: 512
    type: "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
    filesystem: "vfat"
    mount: "/boot/efi"
  
  - number: 2
    name: "BIOS"
    size: 1
    type: "21686148-6449-6E6F-744E-656564454649"
    filesystem: "ext4"
    mount: "none"

  - number: 3
    name: "SWAP"
    size: 2048
    type: "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F"
    filesystem: "swap"
    mount: "none"

  - number: 4
    name: "SYSTEM"
    size: 20480
    type: "0FC63DAF-8483-4772-8E79-3D69D8477DE4"
    filesystem: "ext4"
    mount: "/"

  - number: 5
    name: "HOME"
    size: 0  # 0 means use the rest of the disk
    type: "0FC63DAF-8483-4772-8E79-3D69D8477DE4"
    filesystem: "ext4"
    mount: "/home"
```

### Field Reference

| Field | Description | Example |
| :--- | :--- | :--- |
| `number` | Partition number on the disk (1-128). | `1`, `2` |
| `name` | Label for the partition and name of the `.raw` file to clone. | `"SYSTEM"`, `"HOME"` |
| `size` | Size in MB. Use `0` for the last partition to fill the remaining disk space. | `512`, `20480`, `0` |
| `type` | GPT Type GUID (standard identifiers). | `"0FC63DAF-8483-4772-8E79-3D69D8477DE4"` |
| `filesystem` | File system to create (`ext4`, `vfat`, `swap`). | `"ext4"`, `"vfat"` |
| `mount` | Mount point in the target system's `/etc/fstab`. | `"/"`, `"/home"`, `"none"` |

### Common GPT Type GUIDs

- **EFI System Partition (ESP)**: `C12A7328-F81F-11D2-BA4B-00A0C93EC93B`
- **BIOS Boot Partition**: `21686148-6449-6E6F-744E-656564454649`
- **Linux Filesystem**: `0FC63DAF-8483-4772-8E79-3D69D8477DE4`
- **Linux Swap**: `0657FD6D-A4AB-43C4-84E5-0933C84B4F4F`

### Advanced Behavior

- **Cloning Logic**: If the name is **structural** (`BIOS`, `EFI`, `SWAP`), MCS only creates and formats the partition. For other names (`SYSTEM` or `HOME`), it looks for a `<name>.raw` file to clone.
- **Dynamic Sizing**: Setting `size: 0` tells the MCS engine to calculate the disk geometry and extend that partition to use **100% of the remaining sectors**.
- **FSTAB Generation**: The system automatically generates the target `/etc/fstab` using the `mount` and `filesystem` fields with **PARTUUID**.

---

## ✅ Integrity Verification

MCS supports **SHA-256 integrity verification** for `.raw` partition files to detect corruption or tampering.

Every project directory should include a `checksums.sha256` file. MCS uses it to verify the integrity of the project definition (`partition.yml`) and the data partitions (`.raw` files).

```text
<sha256_hash> <size_in_bytes> <filename>.raw
```

**Example:**

```text
f3e5b3c2... 1240 partition.yml
e3b0c442... 21474836480 SYSTEM.raw
a7ffc6f8... 5368709120 HOME.raw
```

- **`<size_in_bytes>`**: Exact size of the `.raw` file. MCS reads precisely this number of bytes from the target block device to compute the hash.

On your server or build machine, generate the file using this loop:

```bash
# Generate checksums for the project definition and partitions
for f in partition.yml *.raw; do
  [ -f "$f" ] || continue
  echo "$(sha256sum "$f" | awk '{print $1}') $(stat -c %s "$f") $f"
done > checksums.sha256
```

### Disabling verification

In high-speed local networks, you can disable checksum verification to save time via the **Settings** menu in the TUI (saved in `/mcsdata/config.yml`).

---

## 🔄 Image Lifecycle

1. **Creation**: Create a master system image using your preferred method (e.g., QEMU, VirtualBox).
2. **Extraction**: Extract the partitions to RAW files (`SYSTEM.raw` and `HOME.raw`).
3. **Configuration**: Create the `partition.yml` and `checksums.sha256`.
4. **Upload**: Upload the project directory to the server's `/pool/mcs/` path.
5. **Discovery**: Boot MCS on a client machine. The new project will automatically appear.

---

## 💾 Local Storage (USB Data Partition)

When a project is downloaded via the TUI, it is stored in the persistent data partition of the MCS USB drive.

- **Mount Point**: `/mcsdata`
- **Projects Directory**: `/pool/mcs/` (inside the data partition).

You can also manually load projects by copying directories directly to the USB.

---

## 🔒 Security & Certificates

To ensure secure communication, MCS implements automatic certificate handling:

1. On boot, it identifies the `SERVER_URL`.
2. It attempts to download the CA certificate using `openssl s_client`.
3. The certificate is added to the local trust store (`update-ca-certificates`).
4. This allows `wget` to perform secure HTTPS downloads without warnings.
