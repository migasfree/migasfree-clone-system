# Migasfree Clone System (MCS)

[![Version](https://img.shields.io/badge/version-1.1-blue.svg)](VERSION)

**Migasfree Clone System (MCS)** is a lightweight, Alpine Linux-based utility designed for rapid system imaging and cloning. It provides a simple Text User Interface (TUI) to manage, download, and deploy system images across BIOS and UEFI environments.

---

## 📚 Documentation

The documentation is organized by target audience to help you find the right information quickly.

### 🛠️ Operator Guide (End-Users)

- [End-User Guide](docs/user_guide.md): Getting the ISO, creating a bootable USB, booting, and operating the TUI.

### ⚙️ Administrator Guide (SysAdmins)

- [Server Setup & Image Management](docs/server_setup.md): HTTP pool structure, `partition.yml`, checksums, and the image lifecycle.
- [Configuration Reference](docs/configuration.md): Build-time (`mcs.conf`) and runtime (`config.yml`) settings.

### 💻 Developer Reference

- [Architecture & Design](docs/architecture.md): Multi-stage build process and high-level system design.
- [Shell Functions](docs/functions.md): Internal library documentation.
- [Testing with QEMU](docs/testing.md): Virtualized testing environment guide.
- [Architecture Decision Records (ADR)](docs/adr/): History of key technical decisions.

---

## 🚀 Quick Start (Builders & Admins)

To build, test, and deploy MCS, your host system needs a Linux environment with `make`, `sudo`, `docker`, `parted`, and `qemu` installed.

### 1. Building the Image

Generate the MCS bootable ISO from the source code:

```bash
make build
```

The resulting image will be located at `artifacts/mcs-<version>.iso`.

### 2. Testing in QEMU

Safely boot the generated ISO in a virtual machine to verify it works:

```bash
make qemu-clone
```

### 3. Deploying to a Physical USB

To write the ISO to a physical USB drive, use our interactive script which provides safety checks and prevents accidental data loss:

```bash
make flash
```

#### 📌 First Boot Expansion

On the **very first boot** from a newly created USB, MCS will automatically resize its internal data partition (`MCS_DATA`) to occupy **all remaining free space** on the drive. This prepares the environment for storing local images without any manual intervention.

---

## 🖥️ Usage Summary

Once booted (either in QEMU or via USB), you will access the main TUI menu:

1. **Network Clone**: Stream a project directory directly from the remote server to the local disk using high-speed streaming.
2. **Local Clone**: Clone a project already stored in the USB's data partition to the destination disk.
3. **Local Images**: List, download, or delete system projects to/from the USB's storage.
4. **Settings**: Configure the server URL, IP, keyboard layout, and checksum verification.

### Server Requirements

MCS expects a `catalog.json` file at the pool root (`http://<SERVER>/pool/mci/catalog.json`) listing available projects. See the [Server Setup](docs/server_setup.md) guide for the format and the [Architecture](docs/architecture.md) document for details on the project directory structure.
