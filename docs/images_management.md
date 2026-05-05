# Image Management & Repositories

This document explains how system images are stored, discovered, and managed within the **Migasfree Clone System (MCS)** ecosystem.

## 📂 The Image Pool

MCS is designed to pull system images from a centralized repository known as the **Image Pool**. This allows administrators to maintain a single source of truth for all deployable system images.

### Remote Server Structure

The remote server must serve files over HTTP/HTTPS. By default, MCS looks for projects in the following path:
`http://<SERVER_URL>/pool/mcs/`

**Requirements for the remote server:**
- **Format**: Images must be stored within **project directories**. Each directory contains the raw partition files:
  - `SYSTEM.raw`: The root filesystem partition.
  - `DATA.raw`: The data/user partition (or a base image).
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

## ⚙️ Configuration

The image server location is defined in `/mcsdata/config.yml`:

```yaml
settings:
  server: your-server.org
  keymap: es
```

You can change this URL at any time using the **Settings** menu in the MCS TUI.

---

## 🔄 Image Lifecycle

1. **Creation**: Create a master system image using your preferred method (e.g., QEMU, VirtualBox).
2. **Extraction**: Extract the partitions to RAW files (`SYSTEM.raw` and `DATA.raw`).
3. **Upload**: Create a directory for your project in the server's `/pool/mcs/` path and upload the `.raw` files.
4. **Discovery**: Boot MCS on a client machine. The new project will automatically appear in the **Local Images > Download** menu.
5. **Deployment**: Download the project to the USB and use the **Clone** menu to deploy it to the local disk using high-speed streaming.
