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
TESTING_SIZE="8G"
```

### Build Script Variables

Alternatively, you can modify the variables at the top of the `build` script:

- **`SIZE_MB`**: Adjust this if you plan to include many large APKs or default images in the `MCS_DATA` partition of the generated file.
- **`SERVER`**: The default domain where MCS will look for system images (`.qcow2`).
- **`KEYMAP`**: The default keyboard layout (e.g., `es`, `us`, `fr`).

### Customizing the Filesystem (Overlay)

Any file placed in `defaults/overlay/` will be copied directly to the root of the generated system. This is the best way to:

- Add custom scripts to `/usr/local/bin`.
- Add pre-configured network settings in `/etc/network/interfaces`.
- Include custom CA certificates in `/usr/local/share/ca-certificates/`.

## 🏃 Runtime Configuration

Once booted, the system stores its configuration in the `MCS_DATA` partition:

- **Path**: `/mcsdata/config.yml`
- **Format**: YAML

```yaml
settings:
  server: inv.org
  keymap: es
```

### Remote Image Server

The image server should host **.qcow2** files in a directory reachable at:
`http://<SERVER_URL>/pool/images/`

MCS uses `wget` to list and download these files. Ensure the server has directory listing enabled or provides an index that `grep` can parse (standard Apache/Nginx autoindex works).

For more details on how to set up your image server, see the [Image Management Guide](images_management.md).

## ⌨️ Keyboard Layouts

MCS uses standard XKB keymaps. Available layouts can be found in `/usr/share/keymaps/xkb/`. You can change the layout at runtime via the **Settings** menu in the TUI.
