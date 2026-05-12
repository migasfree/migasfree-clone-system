load '../helpers/assert'

setup() {
    load '../helpers/mocks'
    setup_mocks
    source_functions
    if [ -z "$_CACHED_JSON_PARTITIONS" ]; then
        export _CACHED_JSON_PARTITIONS=$(yq -o json '.partitions' "${FIXTURES_DIR}/partition.yml")
    fi
    _JSON_PARTITIONS="$_CACHED_JSON_PARTITIONS"
}

teardown() {
    teardown_mocks
}

@test "make_fstab: generates SYSTEM entry with ext4 and errors=remount-ro" {
    run make_fstab "/dev/sda"
    assert_success
    assert_output_contains "PARTUUID="
    assert_output_contains "errors=remount-ro"
    assert_output_contains "0 1"
}

@test "make_fstab: generates EFI entry with vfat and umask=0077" {
    run make_fstab "/dev/sda"
    assert_output_contains "umask=0077"
}

@test "make_fstab: generates HOME entry with defaults" {
    run make_fstab "/dev/sda"
    assert_output_contains "defaults"
    assert_output_contains "0 2"
}

@test "make_fstab: contains /boot/efi mount point" {
    run make_fstab "/dev/sda"
    assert_output_contains "/boot/efi"
}

@test "make_fstab: contains / mount point" {
    run make_fstab "/dev/sda"
    assert_output_contains " / "
}

@test "make_fstab: contains /home mount point" {
    run make_fstab "/dev/sda"
    assert_output_contains "/home"
}

@test "make_fstab: no HOME entry when scheme has no HOME" {
    _JSON_PARTITIONS=$(yq -o json '.partitions' "${FIXTURES_DIR}/partition_minimal.yml")
    run make_fstab "/dev/sda"
    assert_output_not_contains "/home"
}

@test "make_fstab: generates correct line count for full scheme" {
    _JSON_PARTITIONS=$(yq -o json '.partitions' "${FIXTURES_DIR}/partition.yml")
    run make_fstab "/dev/sda"
    local _LINE_COUNT=$(echo "$output" | grep -c "PARTUUID" || true)
    [ "$_LINE_COUNT" -eq 3 ]
}

@test "make_fstab: warnings for unknown partitions with mount point" {
    _JSON_PARTITIONS='[{"number":1,"name":"CUSTOM","mount":"/custom","filesystem":"ext4"}]'
    run make_fstab "/dev/sda"
    assert_success
}
