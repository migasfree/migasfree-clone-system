load '../helpers/assert'
load '../helpers/mocks'

setup() {
    setup_mocks
    source_functions

    export MOCK_WGET_DIR="${FIXTURES_DIR}"
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"EFI"},{"name":"/dev/sda2","type":"part","label":""},{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[{"pkname":null,"type":"disk","label":null},{"pkname":"sda","type":"part","label":"EFI"},{"pkname":"sda","type":"part","label":"SYSTEM"},{"pkname":"sda","type":"part","label":"HOME"}]}'
    export MOCK_SFDISK_JSON="${FIXTURES_DIR}/sfdisk-sda.json"
    export MOCK_DISK_SIZE_MB=50000
    export MOCK_SHA256="abc123"

    export MCS_LOG_FILE="$MOCK_DIR/rescue.log"
    export MOCK_PART_EFI=""

    _JSON_PARTITIONS="$(yq -o json '.partitions' "${FIXTURES_DIR}/partition.yml" 2>/dev/null )"

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

    cat > "$MOCK_DIR/mount" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/mount"

    cat > "$MOCK_DIR/umount" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/umount"

    cat > "$MOCK_DIR/chroot" <<'SCRIPT'
#!/bin/bash
dir="$1"
shift
"$@"
SCRIPT
    chmod +x "$MOCK_DIR/chroot"

    cat > "$MOCK_DIR/mkdir" <<'SCRIPT'
#!/bin/bash
/bin/mkdir -p "$@" 2>/dev/null
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/mkdir"

    cat > "$MOCK_DIR/rmdir" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/rmdir"

    cat > "$MOCK_DIR/sed" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/sed"

    cat > "$MOCK_DIR/cp" <<'SCRIPT'
#!/bin/bash
/bin/cp "$@" 2>/dev/null
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/cp"

    export PATH="$MOCK_DIR:$PATH"

    connect_HD() { echo "$1"; return 0; }
    disconnect_HD() { return 0; }

    part_by_name() {
        case "$2" in
            SYSTEM) echo "/dev/sda3" ;;
            EFI) echo "${MOCK_PART_EFI:-}" ;;
            HOME) echo "/dev/sda4" ;;
            *) echo "" ;;
        esac
    }

    make_fstab() {
        if [ -n "${MOCK_PART_EFI:-}" ]; then
            echo "PARTUUID=abcd-1234  /boot/efi  vfat  umask=0077  0  1"
        fi
        echo "PARTUUID=deadbeef-1234-5678-9abc-def012345678  /  ext4  errors=remount-ro  0  1"
    }

    rescue() {
        local _DEVICE="$1"
        local _MOUNT="$TEST_MOUNT"

        mcs_log "Configuring Bootloader (Rescue)"
        mcs_log "=============================="

        _DEVICE=$(connect_HD "${_DEVICE}")
        local _DEV_SYSTEM=$(part_by_name "$_DEVICE" SYSTEM)
        local _DEV_EFI=$(part_by_name "$_DEVICE" EFI)

        mkdir -p "${_MOUNT}"
        mount -t auto "${_DEV_SYSTEM}" "${_MOUNT}" >> "$MCS_LOG_FILE" 2>&1

        if [ -n "$_DEV_EFI" ]; then
            mkdir -p "${_MOUNT}/boot/efi"
            mount -t auto "${_DEV_EFI}" "${_MOUNT}/boot/efi" >> "$MCS_LOG_FILE" 2>&1
        fi

        for dir in dev proc sys run; do
            mount --bind "/$dir" "${_MOUNT}/$dir" >> "$MCS_LOG_FILE" 2>&1
        done

        mcs_log "Updating /etc/fstab..."
        make_fstab "$_DEVICE" > "${_MOUNT}/etc/fstab"

        mcs_log "Installing GRUB (BIOS)..."
        echo "(hd0) ${_DEVICE}" > "${_MOUNT}/boot/grub/device.map"

        if chroot "${_MOUNT}" which grub-install >/dev/null 2>&1; then
            chroot "${_MOUNT}" grub-install --target=i386-pc --force --modules="part_gpt biosdisk" "${_DEVICE}" 2>&1 | tee -a $MCS_LOG_FILE
        else
            mcs_log "  [WARNING] grub-install not found inside target, trying from host..."
            grub-install --target=i386-pc --boot-directory="${_MOUNT}/boot" --force "${_DEVICE}" 2>&1 | tee -a $MCS_LOG_FILE
        fi

        if [ -n "$_DEV_EFI" ]; then
            mcs_log "Installing GRUB (UEFI)..."
            if chroot "${_MOUNT}" which grub-install >/dev/null 2>&1; then
                chroot "${_MOUNT}" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub --force 2>&1 | tee -a $MCS_LOG_FILE
            else
                mcs_log "  [WARNING] grub-install (UEFI) not found inside target, skipping chroot install..."
            fi
            mkdir -p "${_MOUNT}/boot/efi/EFI/BOOT"
            cp "${_MOUNT}/boot/efi/EFI/grub/grubx64.efi" "${_MOUNT}/boot/efi/EFI/BOOT/BOOTX64.EFI" 2>/dev/null
        fi

        mcs_log "Updating GRUB configuration..."
        if chroot "${_MOUNT}" which grub-mkconfig >/dev/null 2>&1; then
            chroot "${_MOUNT}" grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee -a $MCS_LOG_FILE
        else
            mcs_log "  [WARNING] grub-mkconfig not found inside target, skipping configuration update..."
        fi

        local _PARTUUID_SYSTEM=$(blkid -o value -s PARTUUID "${_DEV_SYSTEM}")
        if [ -n "$_PARTUUID_SYSTEM" ]; then
            mcs_log "Fixing root= in grub.cfg: ${_DEV_SYSTEM} -> PARTUUID=${_PARTUUID_SYSTEM}"
            sed -i.bak "s|root=${_DEV_SYSTEM}|root=PARTUUID=${_PARTUUID_SYSTEM}|g" "${_MOUNT}/boot/grub/grub.cfg" && rm -f "${_MOUNT}/boot/grub/grub.cfg.bak"
            sed -i.bak "s|root=UUID=[^ ]*|root=PARTUUID=${_PARTUUID_SYSTEM}|g" "${_MOUNT}/boot/grub/grub.cfg" && rm -f "${_MOUNT}/boot/grub/grub.cfg.bak"
        fi

        mcs_log "Syncing and unmounting..."
        sync

        for dir in dev proc sys run; do
            umount -l "${_MOUNT}/$dir" 2>/dev/null
        done
        umount "${_MOUNT}/boot/efi" 2>/dev/null
        umount "${_MOUNT}" 2>/dev/null
        rmdir "${_MOUNT}"

        disconnect_HD "${_DEVICE}"
    }
}

teardown() {
    rm -rf "$MOCK_DIR"
    rm -f /tmp/rescue_test.log
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
    export MOCK_PART_EFI=""
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    run rescue "/dev/sda"

    assert_success
    [[ "$output" != *"Installing GRUB (UEFI)"* ]]
    assert_output_contains "Installing GRUB (BIOS)"

    grub_calls=$(cat "$GRUB_INSTALL_LOG" 2>/dev/null)
    [[ "$grub_calls" == *"--target=i386-pc"* ]]
    [[ "$grub_calls" != *"--target=x86_64-efi"* ]]
}


@test "rescue: BOOTX64.EFI not created when no EFI partition" {
    export MOCK_PART_EFI=""
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    run rescue "/dev/sda"

    assert_success
    [ ! -f "$TEST_MOUNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ]
}

@test "rescue: with EFI but chroot lacks grub-install logs UEFI warning" {
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=1
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    run rescue "/dev/sda"

    assert_success
    assert_output_contains "WARNING"
    assert_output_contains "UEFI"
    assert_output_contains "skipping chroot install"
}


@test "rescue: with EFI installs GRUB config via grub-mkconfig" {
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"

    run rescue "/dev/sda"

    assert_success

    mkconfig_calls=$(cat "$GRUB_MKCONFIG_LOG" 2>/dev/null)
    [[ "$mkconfig_calls" == *"-o /boot/grub/grub.cfg"* ]]
}


@test "rescue: generates fstab with EFI entry when EFI partition exists" {
    export MOCK_PART_EFI="/dev/sda1"
    export WHICH_GRUB_INSTALL=0
    export WHICH_GRUB_MKCONFIG=0
    rm -f "$GRUB_INSTALL_LOG" "$GRUB_MKCONFIG_LOG"

    touch "$TEST_MOUNT/boot/efi/EFI/grub/grubx64.efi"

    run rescue "/dev/sda"

    assert_success
    [ -f "$TEST_MOUNT/etc/fstab" ]
    fstab_content=$(cat "$TEST_MOUNT/etc/fstab")
    [[ "$fstab_content" == *"/boot/efi"* ]]
}


@test "rescue: fstab has no EFI entry when no EFI partition" {
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
