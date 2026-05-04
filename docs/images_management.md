# Image Management & Repositories

This document explains how system images are stored, discovered, and managed within the **Migasfree Clone System (MCS)** ecosystem.

## 📂 The Image Pool

MCS is designed to pull system images from a centralized repository known as the **Image Pool**. This allows administrators to maintain a single source of truth for all deployable system images.

### Remote Server Structure

The remote server must serve files over HTTP/HTTPS. By default, MCS looks for images in the following path:
`http://<SERVER_URL>/pool/images/`

**Requirements for the remote server:**
- **Format**: Images must be in **`.qcow2`** format.
- **Directory Listing**: The web server must have directory listing enabled (Apache `mod_autoindex` or Nginx `autoindex on`). MCS parses the HTML index to present the list of available images in the TUI.
- **Naming**: Use descriptive filenames (e.g., `vitalinux-3.2-primaria.qcow2`).

---

## 💾 Local Storage

When an image is downloaded, it is stored in the persistent data partition of the MCS USB drive.

- **Mount Point**: `/mcsdata`
- **Images Directory**: `/mcsdata/images/`

You can also manually load images into the system by copying `.qcow2` files directly to this directory from another computer.

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

1. **Creation**: Create a master system image using your preferred method (e.g., QEMU, VirtualBox) and convert it to QCOW2.
2. **Upload**: Upload the `.qcow2` file to your organization's `/pool/images/` directory.
3. **Discovery**: Boot MCS on a client machine. The new image will automatically appear in the **Images > Download** menu.
4. **Deployment**: Download the image to the USB and use the **Clone** menu to deploy it to the local disk.
