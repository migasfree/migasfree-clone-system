# Configuration Guide

The Migasfree Clone System (MCS) can be configured at build time and runtime.

## 🏗️ Build-Time Configuration

### The `mcs.conf` file

You can manage image sizes and testing options by editing **`mcs.conf`** at the root of the repository. This file is loaded by the `build` script to configure the image creation process and the testing environment.

> [!NOTE]
> Settings in `mcs.conf` (like `SERVER_URL` and `KEYMAP`) define the *initial* defaults for the generated system. Once the image is built, these can only be changed at runtime by editing `/mcsdata/config.yml` or using the TUI Settings menu.

```bash
# Main MCS image size (in MB)
MCS_SIZE_MB="3072"

# Whether to create a testing image for QEMU (true/false)
CREATE_TESTING="true"

# Testing image name
TESTING_NAME="mcs-testing.iso"

# Testing image size (e.g., 8G, 16G, 32G)
TESTING_SIZE="12G"

# Fixed UUID for the motherboard (SMBIOS) to keep Migasfree identification persistent
TEST_UUID="71656d75-a1b2-c3d4-e5f6-7890abcdef01"
```

### Build Script Variables

Alternatively, you can modify the variables at the top of the **`/scripts/build.sh`** script:

- **`SIZE_MB`**: Adjust this if you plan to include many large APKs or default projects in the `MCS_DATA` partition of the generated file.
- **`SERVER`**: The default domain where MCS will look for system projects.
- **`SERVER_IP`**: (Optional) Static IP address for the server. Use this for lab environments without DNS.
- **`KEYMAP`**: The default keyboard layout (e.g., `es`, `us`, `fr`).

### Customizing the Filesystem (Overlay)

Any file placed in `defaults/overlay/` will be copied directly to the root of the generated system. This is the best way to:

- Add custom scripts to `/usr/local/bin` or `/etc/local.d/`.
- Add custom network or kernel module configurations in `/etc/modules` or `/etc/network/interfaces`.
- Include custom CA certificates in `/usr/local/share/ca-certificates/`.

## 🏃 Runtime Configuration

Once booted, the system stores its configuration in the `MCS_DATA` partition:

- **Path**: `/mcsdata/config.yml`
- **Format**: YAML

```yaml
settings:
  server: inv.org
  server_ip: ""
  keymap: es
  verify_checksums: true
  promoted: true
```

### Config Properties
- **`server`**: The server domain/URL where MCS will look for system projects.
- **`server_ip`**: (Optional) Static IP address override for the server. Useful for lab environments without DNS.
- **`keymap`**: The standard keyboard layout mapped at runtime (e.g. `es`, `us`).
- **`verify_checksums`**: Boolean (`true`/`false`) specifying whether to perform SHA-256 validation of partition image parts after cloning.
- **`promoted`**: Boolean (`true`/`false`) filter controlling which remote images appear in the TUI Network menus:
  - `true` (default): Shows only stable/promoted images (where `enabled` is not `false` in `catalog.json`).
  - `false`: Shows only non-promoted testing/freshly built images (where `enabled` is `false` in `catalog.json`).


## ⌨️ Keyboard Layouts

MCS uses standard XKB keymaps. Available layouts can be found in `/usr/share/keymaps/xkb/`. You can change the layout at runtime via the **Settings** menu in the TUI.
