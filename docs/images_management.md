# Image Management & Repositories

This document explains how system images are stored, discovered, and managed within the **Migasfree Clone System (MCS)** ecosystem.

## 📂 The Image Pool

MCS is designed to pull system images from a centralized repository known as the **Image Pool**. This allows administrators to maintain a single source of truth for all deployable system images.

### Remote Server Structure

The remote server must serve files over HTTP/HTTPS. By default, MCS looks for projects in the following path:
`http://<SERVER_URL>/pool/mcs/`

**Requirements for the remote server:**

- **Format**: Images must be stored within **project directories**. Each directory contains:
  - `partition.yml` **(mandatory)**: Partition layout definition (see [Partitioning Guide](partitioning.md)).
  - `SYSTEM.raw`: The root filesystem partition image.
  - `DATA.raw` or `HOME.raw`: The data/user partition image.
  - `checksums.sha256` **(optional)**: SHA-256 checksums for integrity verification (see below).

- **Directory Listing**: The web server must have directory listing enabled (Apache `mod_autoindex` or Nginx `autoindex on`). MCS parses the HTML index to identify available project directories.
- **Naming**: Use descriptive directory names (e.g., `inv.org_lnx-1`).

---

## 💾 Local Storage

When a project is downloaded, it is stored in the persistent data partition of the MCS USB drive.

- **Mount Point**: `/mcsdata` (locally known as `IMAGES_DIR` in the TUI).
- **Projects Directory**: `/pool/mcs/` (inside the data partition).

You can also manually load projects into the system by copying project directories directly to the USB's data partition.

---

## 🔒 Security & Certificates

To ensure secure communication and verify the identity of the image server, MCS implements an automatic certificate handling mechanism:

1. On boot, MCS identifies the `SERVER_URL`.
2. It attempts to download the CA certificate from the server using `openssl s_client`.
3. The certificate is added to the local trust store (`update-ca-certificates`).
4. This allows `wget` to perform secure HTTPS downloads without certificate warnings.

---

## ✅ Integrity Verification

MCS supports **SHA-256 integrity verification** for `.raw` partition files to detect corruption or tampering during download and cloning.

### The `checksums.sha256` file

Every project directory can include an optional `checksums.sha256` file. If present, MCS automatically verifies that the cloned data matches the expected checksum. The file follows this format:

```text
<sha256_hash> <size_in_bytes> <filename>.raw
```

Example:

```text
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 21474836480 SYSTEM.raw
a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a  5368709120 HOME.raw
```

- **`<sha256_hash>`**: 64-character lowercase hex SHA-256 digest of the `.raw` file.
- **`<size_in_bytes>`**: Exact size of the `.raw` file in bytes. MCS reads precisely this number of bytes from the target partition for verification.
- **`<filename>.raw`**: Must match the partition name defined in `partition.yml` (e.g., `SYSTEM.raw`, `HOME.raw`).

### How verification works

1. When MCS starts a clone (network or local), `load_partition_scheme` looks for `checksums.sha256` alongside `partition.yml`.
2. If the file is **missing**, MCS logs a warning and proceeds without verification (backward-compatible).
3. If present, after writing each `.raw` image to the target partition, MCS calls `verify_partition_checksum`:
   - Reads the expected SHA-256 and byte size from the file.
   - Reads exactly `<size_in_bytes>` bytes from the target block device.
   - Computes the actual SHA-256 digest and compares it to the expected value.
4. If the checksums **match**, a `[OK]` is logged. If they **mismatch**, a `[ERROR] Checksum MISMATCH` entry is written to the log — but the clone continues (non-blocking by design).

### Generating checksums

On your server or build machine, generate `checksums.sha256` with a simple loop:

```bash
for f in *.raw; do
  echo "$(sha256sum "$f" | awk '{print $1}') $(stat -c %s "$f") $f"
done > checksums.sha256
```

Resultado:

```text
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 21474836480 SYSTEM.raw
a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a 5368709120 HOME.raw
```

O manualmente para un solo fichero:

```bash
SIZE=$(stat -c %s SYSTEM.raw)
SHA=$(sha256sum SYSTEM.raw | awk '{print $1}')
echo "$SHA $SIZE SYSTEM.raw" >> checksums.sha256
```

### Disabling verification

In high-speed local networks where bandwidth is reliable and risk of corruption is low, you can disable checksum verification to save time. Go to **Settings > Verify integrity** in the MCS TUI and toggle it to `false`. The setting is persisted in `/mcsdata/config.yml`:

```yaml
settings:
  server: your-server.org
  server_ip: ""
  keymap: es
  verify_checksums: true   # set to false to skip SHA-256 verification
```

When disabled, MCS skips the post-clone checksum read entirely — no time penalty.

---

## ⚙️ Configuration

The system settings are defined in `/mcsdata/config.yml`:

```yaml
settings:
  server: your-server.org
  server_ip: ""
  keymap: es
  verify_checksums: true
```

You can change these settings at any time using the **Settings** menu in the MCS TUI.

---

## 🔄 Image Lifecycle

1. **Creation**: Create a master system image using your preferred method (e.g., QEMU, VirtualBox).
2. **Extraction**: Extract the partitions to RAW files (`SYSTEM.raw` and `DATA.raw`).
3. **Upload**: Create a directory for your project in the server's `/pool/mcs/` path and upload the `.raw` files.
4. **Discovery**: Boot MCS on a client machine. The new project will automatically appear in the **Local Images > Download** menu.
5. **Deployment**: Download the project to the USB and use the **Clone** menu to deploy it to the local disk using high-speed streaming.
