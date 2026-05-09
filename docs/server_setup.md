# Server Setup & Image Management

This document explains how system images are stored on a centralized server, how to configure their partitioning, and the lifecycle of managing projects in the **Migasfree Clone System (MCS)**.

## 📂 The Image Pool

MCS is designed to pull system images from a centralized repository known as the **Image Pool**. This allows administrators to maintain a single source of truth for all deployable system images.

### Remote Server Structure

The remote server must serve files over HTTP/HTTPS. By default, MCS looks for projects in the following path:
`http://<SERVER_URL>/pool/mcs/`

**Requirements for the remote server:**

- **Format**: Images must be stored within **project directories**.
- **Project Index**: A `projects.json` file at the pool root listing all available projects. MCS fetches this file instead of parsing directory listings. See format below.
- **Naming**: Use descriptive directory names (e.g., `inv.org_lnx-1`).

Each project directory must contain:

- `partition.yml` **(mandatory)**: Partition layout definition.
- `SYSTEM.raw`: The root filesystem partition image.
- `HOME.raw`: The data/user partition image.
- `checksums.sha256` **(optional)**: SHA-256 checksums for integrity verification.

### `projects.json`

This file indexes all available projects. MCS fetches it from `http://<SERVER_URL>/pool/mcs/projects.json` to populate the cloning menus.

**Format:**

```json
[
  {"name": "ubuntu-22-04",  "enabled": true,  "description": "Ubuntu 22.04 LTS"},
  {"name": "windows-10",    "enabled": true,  "description": "Windows 10 Enterprise"},
  {"name": "centos-7",      "enabled": false, "description": "CentOS 7 (discontinued)"}
]
```

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `name` | string | — | Project directory name. Must match the directory on the server. |
| `enabled` | boolean | `true` | Controls visibility. When `false`, the project is not listed in MCS menus. |
| `description` | string | `""` | Optional human-readable description shown alongside the project name. |

Projects with `enabled: false` are filtered out by MCS. This allows deactivating projects without removing their files from the server.

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

## 🤖 MCS Build API (migasfree/manager)

The Manager service exposes two endpoints to programmatically build MCS project images.

### Queue a Build

Triggers an asynchronous build for a Migasfree project. On completion, `SYSTEM.raw`, `HOME.raw`, `partition.yml`, `checksums.sha256`, and `projects.json` are placed in `/mnt/cluster/datashares/<STACK>/pool/mcs/<project-slug>/`.

```http
POST /manager/v1/private/mcs/build
Authorization: Token <superadmin_token>
Content-Type: application/json

{"project_id": <integer>}
```

**Response** `200 OK`:

```json
{
  "task_id": "9183ccb6-f9b1-4b61-8e74-17d88ef69a16"
}
```

### Poll Build Status

```http
GET /manager/v1/private/mcs/build/{task_id}/status
```

**Response** `200 OK`:

```json
{
  "task_id": "9183ccb6-f9b1-4b61-8e74-17d88ef69a16",
  "status": "building",
  "progress": 0,
  "message": "Building image: Step 8/12",
  "created_at": "2026-05-09T17:47:38.394968+00:00",
  "updated_at": "2026-05-09T18:01:53.805228+00:00"
}
```

**Status values:**

| Status | Description |
| :--- | :--- |
| `queued` | Waiting for worker |
| `building` | Docker image build (message shows current `Step N/M`) |
| `exporting` | Container filesystem being extracted |
| `creating` | `.raw` images being created |
| `finalizing` | Generating metadata and moving to pool |
| `completed` | Build successful |
| `error` | Build failed (message has details) |

### 🔍 Following Progress

To monitor the build progress in real-time, you should poll the **Status Endpoint** periodically (e.g., every 5 seconds).

The `message` field provides live feedback from the build pipeline:

- During the **`building`** phase, the message is updated automatically with the current Docker build step (e.g., `"Building image: Step 4/12"`).
- If the build enters the **`error`** state, the `message` will contain the last relevant error line from the Docker output or the system logs to help diagnose the failure (e.g., `"Docker build failed: E: Unable to locate package linux-generic"`).

For developers, the full output of the build process can be monitored directly from the server using the following commands:

**Follow logs in real-time:**

```bash
docker logs $(docker ps --filter name=inv_manager -q | head -1) -f
```

**Search for recent build errors:**

```bash
docker logs $(docker ps --filter name=inv_manager -q | head -1) 2>&1 | grep "mcs_builder" | tail -30
```

### Build Lifecycle

1. **Manager receives POST** — validates project exists, pushes task to Redis queue.
2. **Background worker** picks up the task and starts the build pipeline.
3. **Docker image build** — generates a Dockerfile from the project's `base_os`, installs packages.
4. **Filesystem extraction** — exports the container via `docker export | tar -xf -` pipe (no intermediate tar file).
5. **Raw image creation** — `mkfs.ext4 -d` creates `SYSTEM.raw` and `HOME.raw` from the extracted directories, then `resize2fs -M` shrinks them to fit the actual content.
6. **Metadata generation** — creates `partition.yml`, `checksums.sha256`, updates `projects.json`.
7. **Pool deployment** — all files moved to `pool/mcs/<slug>/`.

### Prerequisites

- The project must have `base_os` set in Core (e.g., `debian:13.4`).
- The Manager container needs access to the Docker daemon (`/var/run/docker.sock`).
- Build output is stored in the shared datashares volume.

---

## 🔄 Image Lifecycle

1. **Creation**: Create a master system image using your preferred method (e.g., QEMU, VirtualBox).
2. **Extraction**: Extract the partitions to RAW files (`SYSTEM.raw` and `HOME.raw`).
3. **Configuration**: Create the `partition.yml` and `checksums.sha256`.
4. **Upload**: Upload the project directory to the server's `/pool/mcs/` path.
5. **Indexing**: Add the project to `projects.json` in the pool root. This is how MCS discovers and lists available projects.
6. **Discovery**: Boot MCS on a client machine. The new project will appear in the Network Clone menu.

---

## 💾 Local Storage (USB Data Partition)

When a project is downloaded via the TUI, it is stored in the persistent data partition of the MCS USB drive.

- **Mount Point**: `/mcsdata`
- **Projects Directory**: `/mcsdata/images/`
- **Local Project Index**: After each download, MCS saves a copy of `projects.json` in `/mcsdata/images/projects.json`. This allows local clone and list menus to show project descriptions even when offline. The file is overwritten on each subsequent download from the same server.

You can also manually load projects by copying directories directly to the USB's `images/` folder. Note that manually added projects will not have descriptions unless `projects.json` is also updated.

---

## 🔒 Security & Certificates

To ensure secure communication, MCS implements automatic certificate handling:

1. On boot, it identifies the `SERVER_URL`.
2. It attempts to download the CA certificate using `openssl s_client`.
3. The certificate is added to the local trust store (`update-ca-certificates`).
4. This allows `wget` to perform secure HTTPS downloads without warnings.
