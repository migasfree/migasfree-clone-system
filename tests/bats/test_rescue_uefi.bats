load '../helpers/assert'
load '../helpers/mocks'

setup() {
    setup_mocks
    source_functions

    export MOCK_WGET_DIR="${FIXTURES_DIR}"
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda2","type":"part","label":""},{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[{"pkname":null,"type":"disk","label":null},{"pkname":"sda","type":"part","label":"SYSTEM"},{"pkname":"sda","type":"part","label":"HOME"}]}'
    export MOCK_SFDISK_JSON="${FIXTURES_DIR}/sfdisk-sda.json"
    export MOCK_DISK_SIZE_MB=50000
    export MOCK_SHA256="abc123"

    export MCS_LOG_FILE="$MOCK_DIR/rescue.log"
    export MOCK_PART_EFI=""

    # Cache JSON partitions to avoid redundant yq calls (Speed Optimization)
    if [ -z "$_CACHED_JSON_PARTITIONS" ]; then
        export _CACHED_JSON_PARTITIONS="$(yq -o json '.partitions' "${FIXTURES_DIR}/partition.yml" 2>/dev/null )"
    fi
    export _JSON_PARTITIONS="$_CACHED_JSON_PARTITIONS"

    export TEST_MOUNT="$MOCK_DIR/mnt/rescue"
    mkdir -p "$TEST_MOUNT/boot/efi/EFI/grub"
    mkdir -p "$TEST_MOUNT/boot/grub"
    mkdir -p "$TEST_MOUNT/etc"
    mkdir -p "$TEST_MOUNT/dev" "$TEST_MOUNT/proc" "$TEST_MOUNT/sys" "$TEST_MOUNT/run"
    touch "$TEST_MOUNT/boot/grub/grub.cfg"

    export GRUB_INSTALL_LOG="$MOCK_DIR/grub_install_calls"
    export GRUB_MKCONFIG_LOG="$MOCK_DIR/grub_mkconfig_calls"
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    cat > "$MOCK_DIR/grub-install" <<'SCRIPT'
#!/bin/bash
echo "$*" >> "$GRUB_INSTALL_LOG"
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/grub-install"

    cat > "$MOCK_DIR/grub-mkconfig" <<'SCRIPT'
#!/bin/bash
echo "$*" >> "$GRUB_MKCONFIG_LOG"
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/grub-mkconfig"

    cat > "$MOCK_DIR/which" <<'SCRIPT'
#!/bin/bash
case "$*" in
    *grub-install*) exit "${WHICH_GRUB_INSTALL:-0}" ;;
    *grub-mkconfig*) exit "${WHICH_GRUB_MKCONFIG:-0}" ;;
    *) /usr/bin/which "$@" 2>/dev/null ;;
esac
SCRIPT
    chmod +x "$MOCK_DIR/which"

    cat > "$MOCK_DIR/chroot" <<'SCRIPT'
#!/bin/bash
dir="$1"
shift
"$@"
SCRIPT
    chmod +x "$MOCK_DIR/chroot"

    cat > "$MOCK_DIR/cp" <<'SCRIPT'
#!/bin/bash
/bin/cp "$@" 2>/dev/null
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/cp"
}

teardown() {
    teardown_mocks
}


@test "rescue: with EFI partition installs both BIOS and UEFI GRUB" {
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"

    run rescue "/dev/sda"

    assert_success
    assert_output_contains "Installing GRUB (UEFI)"
    assert_output_contains "Installing GRUB (BIOS)"

    grub_calls=$(cat "$GRUB_INSTALL_LOG" 2>/dev/null)
    [[ "$grub_calls" == *"--target=i386-pc"* ]]
    [[ "$grub_calls" == *"--target=x86_64-efi"* ]]
}


@test "rescue: BOOTX64.EFI fallback copy exists after rescue with EFI" {
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"

    run rescue "/dev/sda"

    assert_success
    [ -f "$TEST_MOUNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ]
}


@test "rescue: without EFI partition skips UEFI, installs only BIOS" {
    # Remove EFI partition from mock JSON and from partition scheme
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    export _JSON_PARTITIONS='[{"name":"SYSTEM","number":"3","mount":"/","filesystem":"ext4"},{"name":"HOME","number":"4","mount":"/home","filesystem":"ext4"}]'
    export MOCK_PART_EFI=""
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    run rescue "/dev/sda"

    assert_success
    [[ "$output" != *"Installing GRUB (UEFI)"* ]]
    assert_output_contains "Installing GRUB (BIOS)"
}


@test "rescue: BOOTX64.EFI not created when no EFI partition" {
    # Remove EFI partition from mock JSON and from partition scheme
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    export _JSON_PARTITIONS='[{"name":"SYSTEM","number":"3","mount":"/","filesystem":"ext4"},{"name":"HOME","number":"4","mount":"/home","filesystem":"ext4"}]'
    export MOCK_PART_EFI=""
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    run rescue "/dev/sda"

    assert_success
    [ ! -f "$TEST_MOUNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ]
}

@test "rescue: with EFI but chroot lacks grub-install logs UEFI warning" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"EFI"},{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    export _JSON_PARTITIONS='[{"name":"EFI","number":"1","mount":"/boot/efi","filesystem":"vfat"},{"name":"SYSTEM","number":"3","mount":"/","filesystem":"ext4"},{"name":"HOME","number":"4","mount":"/home","filesystem":"ext4"}]'
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=1
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    run rescue "/dev/sda"

    assert_success
    assert_output_contains "WARNING"
    assert_output_contains "UEFI"
    assert_output_contains "failed or not found inside target"
}


@test "rescue: with EFI installs GRUB config via grub-mkconfig" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"EFI"},{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    export _JSON_PARTITIONS='[{"name":"EFI","number":"1","mount":"/boot/efi","filesystem":"vfat"},{"name":"SYSTEM","number":"3","mount":"/","filesystem":"ext4"},{"name":"HOME","number":"4","mount":"/home","filesystem":"ext4"}]'
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    mkdir -p "$TEST_MOUNT/boot/efi/EFI/grub"
    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"

    run rescue "/dev/sda"

    assert_success

    mkconfig_calls=$(cat "$GRUB_MKCONFIG_LOG" 2>/dev/null)
    [[ "$mkconfig_calls" == *"-o /boot/grub/grub.cfg"* ]]
}


@test "rescue: generates fstab with EFI entry when EFI partition exists" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"EFI"},{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    export _JSON_PARTITIONS='[{"name":"EFI","number":"1","mount":"/boot/efi","filesystem":"vfat"},{"name":"SYSTEM","number":"3","mount":"/","filesystem":"ext4"},{"name":"HOME","number":"4","mount":"/home","filesystem":"ext4"}]'
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    mkdir -p "$TEST_MOUNT/boot/efi/EFI/grub"
    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"

    run rescue "/dev/sda"

    assert_success
    [ -f "$TEST_MOUNT/etc/fstab" ]
    fstab_content=$(cat "$TEST_MOUNT/etc/fstab")
    [[ "$fstab_content" == *"/boot/efi"* ]]
}


@test "rescue: fstab has no EFI entry when no EFI partition" {
    # Remove EFI partition from mock JSON and from partition scheme
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    export _JSON_PARTITIONS='[{"name":"SYSTEM","number":"3","mount":"/","filesystem":"ext4"},{"name":"HOME","number":"4","mount":"/home","filesystem":"ext4"}]'
    export MOCK_PART_EFI=""
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    run rescue "/dev/sda"

    assert_success
    [ -f "$TEST_MOUNT/etc/fstab" ]
    fstab_content=$(cat "$TEST_MOUNT/etc/fstab")
    [[ "$fstab_content" != *"/boot/efi"* ]]
}


@test "rescue: applies PARTUUID fix in grub.cfg" {
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"
    echo "root=/dev/sda3 ro quiet" > "$TEST_MOUNT/boot/grub/grub.cfg"
    rm -f "$MCS_LOG_FILE"

    run rescue "/dev/sda"

    assert_success
    assert_log_contains "$MCS_LOG_FILE" "Fixing root="
}


@test "rescue: with NVMe target installs GRUB on nvme device" {
    export MOCK_PART_EFI="/dev/nvme0n1p1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    part_by_name() {
        case "$2" in
            SYSTEM) echo "/dev/nvme0n1p3" ;;
            EFI) echo "/dev/nvme0n1p1" ;;
            HOME) echo "/dev/nvme0n1p4" ;;
            *) echo "" ;;
        esac
    }

    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"
    echo "root=/dev/nvme0n1p3 ro quiet" > "$TEST_MOUNT/boot/grub/grub.cfg"
    rm -f "$MCS_LOG_FILE"

    run rescue "/dev/nvme0n1"

    assert_success
    assert_output_contains "Installing GRUB (BIOS)"
    assert_output_contains "Installing GRUB (UEFI)"

    grub_calls=$(cat "$GRUB_INSTALL_LOG" 2>/dev/null)
    [[ "$grub_calls" == *"/dev/nvme0n1"* ]]
}

@test "rescue: uses --removable flag for UEFI grub-install" {
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG"
    
    mkdir -p "$TEST_MOUNT/boot/efi/EFI/grub"
    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"

    run rescue "/dev/sda"
    
    assert_success
    grub_calls=$(cat "$GRUB_INSTALL_LOG" 2>/dev/null)
    [[ "$grub_calls" == *"--removable"* ]]
}

@test "rescue: hybrid boot - falls back to host grub-install if chroot lacks grub-install" {
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=1  # grub-install not found in target
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG"

    mkdir -p "$TEST_MOUNT/boot/efi/EFI/grub"
    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"

    run rescue "/dev/sda"
    
    assert_success
    assert_log_contains "$MCS_LOG_FILE" "grub-install (UEFI) failed or not found inside target"
    
    # Verify it was called from host (with absolute paths to the mount point)
    grub_calls=$(cat "$GRUB_INSTALL_LOG" 2>/dev/null)
    [[ "$grub_calls" == *"--efi-directory=${TEST_MOUNT}/boot/efi"* ]]
    [[ "$grub_calls" == *"--removable"* ]]
}

@test "rescue: hybrid boot - searches different EFI vendor paths (e.g. debian)" {
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    
    # Setup debian style path
    mkdir -p "$TEST_MOUNT/boot/efi/EFI/debian"
    touch "$TEST_MOUNT/boot/efi/EFI/debian/grubx64.efi"
    # Ensure BOOT path doesn't exist yet
    rm -rf "$TEST_MOUNT/boot/efi/EFI/BOOT"

    run rescue "/dev/sda"
    
    assert_success
    [ -f "$TEST_MOUNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ]
}
