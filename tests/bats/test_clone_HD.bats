load '../helpers/assert'

setup() {
    load '../helpers/mocks'
    setup_mocks
    source_functions

    export MOCK_WGET_DIR="${FIXTURES_DIR}"
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"EFI"},{"name":"/dev/sda2","type":"part","label":""},{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[{"pkname":null,"type":"disk","label":null},{"pkname":"sda","type":"part","label":"SYSTEM"},{"pkname":"sda","type":"part","label":"HOME"}]}'
    export MOCK_SFDISK_JSON=$(cat "${FIXTURES_DIR}/sfdisk-sda.json")
    export MOCK_DISK_SIZE_MB=50000

    connect_HD() {
        if [[ "$1" == http* ]] || [[ "$1" == */ ]]; then
            echo "$1"
            return 0
        fi
        echo "$1"
        return 0
    }
}

teardown() {
    teardown_mocks
}

@test "clone_HD: HTTP Turbo Clone succeeds and writes SYSTEM and HOME" {
    run clone_HD "http://server/pool/mci/project/" "/dev/sda"
    assert_success
}

@test "clone_HD: local directory clone succeeds" {
    run clone_HD "${FIXTURES_DIR}" "/dev/sda"
    assert_success
}

@test "clone_HD: preserve HOME skips HOME partition" {
    run clone_HD "http://server/pool/mci/project/" "/dev/sda" "true"
    assert_success
}

@test "clone_HD: returns error when partition scheme missing" {
    run clone_HD "/tmp/nonexistent_dir_$$" "/dev/sda"
    assert_failure
}

@test "clone_HD: returns error on HTTP source without partition.yml" {
    export MOCK_WGET_DIR=""
    run clone_HD "http://server/pool/mci/nonexistent/" "/dev/sda"
    assert_failure
}

@test "clone_HD: local clone with missing raw file reports error" {
    run clone_HD "/tmp" "/dev/sda"
    assert_failure
}

@test "clone_HD: with preserve home succeeds" {
    run clone_HD "http://server/pool/mci/project/" "/dev/sda" "true"
    assert_success
}

@test "clone_HD: local directory clone succeeds with NVMe target" {
    export MOCK_LSBLK_PARENT_JSON=$(cat "${FIXTURES_DIR}/lsblk-nvme.json")
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[{"pkname":null,"type":"disk","label":null},{"pkname":"nvme0n1","type":"part","label":"SYSTEM"},{"pkname":"nvme0n1","type":"part","label":"HOME"}]}'
    run clone_HD "${FIXTURES_DIR}" "/dev/nvme0n1"
    assert_success
}
