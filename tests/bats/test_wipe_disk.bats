load '../helpers/assert'
load '../helpers/mocks'

setup() {
    setup_mocks
    source_functions

    export MOCK_WGET_DIR="${FIXTURES_DIR}"
    export MOCK_SFDISK_JSON=$(cat "${FIXTURES_DIR}/sfdisk-sda.json")
    export MOCK_DISK_SIZE_MB=50000
    export MOCK_SHA256="abc123"

    export MOCK_DIR_WRITABLE="$MOCK_DIR/writable"
    mkdir -p "$MOCK_DIR_WRITABLE"

    _JSON_PARTITIONS="$(yq -o json '.partitions' "${FIXTURES_DIR}/partition.yml" 2>/dev/null)"
    _VERIFY_CHECKSUMS=0

    connect_HD() {
        if [[ "$1" == http* ]] || [[ "$1" == */ ]]; then
            echo "$1"
            return 0
        fi
        echo "$1"
        return 0
    }
    disconnect_HD() { return 0; }

    SFDISK_WAS_CALLED=""
    MKFS_EXT4_CALLED=""
    MKFS_FAT_CALLED=""

    cat > "$MOCK_DIR/sfdisk" <<'SCRIPT'
#!/bin/bash
echo "$*" >> /tmp/sfdisk_calls
if [ "$1" = "-J" ]; then
    echo "${MOCK_SFDISK_JSON}"
    exit 0
fi
# Regular sfdisk call: record that it was invoked on the device
echo "sfdisk called on $2" >> /tmp/sfdisk_calls
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/sfdisk"

    cat > "$MOCK_DIR/mkfs.ext4" <<'SCRIPT'
#!/bin/bash
echo "mkfs.ext4 $*" >> /tmp/mkfs_calls
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/mkfs.ext4"

    cat > "$MOCK_DIR/mkfs.fat" <<'SCRIPT'
#!/bin/bash
echo "mkfs.fat $*" >> /tmp/mkfs_calls
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/mkfs.fat"

    cat > "$MOCK_DIR/qemu-img" <<'SCRIPT'
#!/bin/bash
touch "${!#}"
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/qemu-img"

    cat > "$MOCK_DIR/umount" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/umount"

    export PATH="$MOCK_DIR:$PATH"
    rm -f /tmp/sfdisk_calls /tmp/mkfs_calls
}

teardown() {
    rm -rf "$MOCK_DIR"
    rm -f /tmp/sfdisk_calls /tmp/mkfs_calls
    rm -f 256000M
}


@test "make_partitions: writes new GPT via sfdisk on target device" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"OLD_LABEL"}]}]}'

    run make_partitions "/dev/sda"

    assert_success
    assert_output_contains "Creating a new GPT partition table"
    assert_output_contains "sfdisk done"

    # Verify sfdisk was called (records in /tmp/sfdisk_calls)
    sfdisk_log=$(cat /tmp/sfdisk_calls 2>/dev/null)
    [[ "$sfdisk_log" == *"sfdisk called"* ]]
}


@test "make_file_systems: creates ext4 on SYSTEM partition" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"EFI"},{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'

    run make_file_systems "/dev/sda"

    assert_success
    assert_output_contains "Creando sistemas de ficheros"

    mkfs_log=$(cat /tmp/mkfs_calls 2>/dev/null)
    [[ "$mkfs_log" == *"mkfs.ext4"* ]]
    [[ "$mkfs_log" == *"mkfs.fat"* ]]
}


@test "clone_HD: succeeds on disk with pre-existing partition labels" {
    # Simulate a disk that previously had different labels
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"OLD_BOOT"},{"name":"/dev/sda2","type":"part","label":"OLD_SYSTEM"}]}]}'
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[{"pkname":null,"type":"disk","label":null},{"pkname":"sda","type":"part","label":"OLD_SYSTEM"}]}'

    run clone_HD "${FIXTURES_DIR}" "/dev/sda"

    assert_success
}


@test "clone_HD: make_HD sequence works on previously partitioned disk" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"OLD_EFI"},{"name":"/dev/sda2","type":"part","label":"OLD_SYSTEM"}]}]}'

    run make_HD "/dev/sda" ""

    assert_success
    assert_output_contains "Creating a new GPT partition table"
    assert_output_contains "Creando sistemas de ficheros"
}


@test "make_partitions: sfdisk output includes type and name fields" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[]}]}'

    run make_partitions "/dev/sda"

    assert_success
    assert_output_contains "sfdisk done"
}


@test "clone_HD: handles empty pre-existing partition table" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[]}'
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[]}'

    run clone_HD "${FIXTURES_DIR}" "/dev/sda"

    assert_success
}


@test "clone_HD: handles disk with no partition table at all" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk"}]}'
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[]}'

    run clone_HD "${FIXTURES_DIR}" "/dev/sda"

    assert_success
}
