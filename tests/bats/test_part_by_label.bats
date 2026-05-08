load '../helpers/assert'

setup() {
    load '../helpers/mocks'
    setup_mocks
    source_functions
}

teardown() {
    teardown_mocks
}

@test "part_by_label: finds SYSTEM partition on /dev/sda" {
    export MOCK_LSBLK_KNAME_JSON='{"blockdevices":[{"kname":null,"type":"disk","label":null},{"kname":"sda3","type":"part","label":"SYSTEM"},{"kname":"sda4","type":"part","label":"HOME"}]}'
    run part_by_label "SYSTEM"
    assert_output_contains "/dev/sda3"
}

@test "part_by_label: finds HOME partition" {
    export MOCK_LSBLK_KNAME_JSON='{"blockdevices":[{"kname":null,"type":"disk","label":null},{"kname":"sda3","type":"part","label":"SYSTEM"},{"kname":"sda4","type":"part","label":"HOME"}]}'
    run part_by_label "HOME"
    assert_success
    [[ "$output" == "/dev/sda4" ]]
}

@test "part_by_label: returns error when label not found" {
    export MOCK_LSBLK_KNAME_JSON='{"blockdevices":[{"kname":null,"type":"disk","label":null}]}'
    run part_by_label "NONEXISTENT"
    assert_failure
}

@test "part_by_label: returns error on empty label" {
    export MOCK_LSBLK_KNAME_JSON='{"blockdevices":[{"kname":null,"type":"disk","label":null}]}'
    run part_by_label ""
    assert_failure
}

@test "part_by_label_on_device: finds SYSTEM on /dev/sda" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"EFI"},{"name":"/dev/sda2","type":"part","label":""},{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    run part_by_label_on_device "/dev/sda" "SYSTEM"
    assert_success
    [[ "$output" == "/dev/sda3" ]]
}

@test "part_by_label_on_device: not found returns empty" {
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"EFI"}]}]}'
    run part_by_label_on_device "/dev/sda" "NONEXISTENT"
    assert_success
    [ -z "$output" ]
}

@test "disk_by_label: finds disk by child partition label" {
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[{"pkname":null,"type":"disk","label":null},{"pkname":"sda","type":"part","label":"SYSTEM"},{"pkname":"sda","type":"part","label":"HOME"}]}'
    run disk_by_label "SYSTEM"
    assert_success
    [[ "$output" == "/dev/sda" ]]
}

@test "disk_by_label: not found returns error" {
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[{"pkname":null,"type":"disk","label":null}]}'
    run disk_by_label "NONEXISTENT"
    assert_failure
}

@test "part_by_id: /dev/sda + 3 = /dev/sda3" {
    run part_by_id "/dev/sda" 3
    [[ "$output" == "/dev/sda3" ]]
}

@test "part_by_id: /dev/nvme0n1 + 1 = /dev/nvme0n1p1" {
    run part_by_id "/dev/nvme0n1" 1
    [[ "$output" == "/dev/nvme0n1p1" ]]
}

@test "part_by_id: /dev/nbd0 + 4 = /dev/nbd0p4" {
    run part_by_id "/dev/nbd0" 4
    [[ "$output" == "/dev/nbd0p4" ]]
}

@test "id_by_part: /dev/sda3 returns 3" {
    export MOCK_LSBLK_REVERSE_JSON='{"blockdevices":[{"kname":"sda3","type":"part","children":[{"kname":"sda","type":"disk"}]}]}'
    run id_by_part "/dev/sda3"
    [[ "$output" == "3" ]]
}

@test "id_by_part: /dev/nvme0n1p5 returns 5" {
    export MOCK_LSBLK_REVERSE_JSON='{"blockdevices":[{"kname":"nvme0n1p5","type":"part","children":[{"kname":"nvme0n1","type":"disk"}]}]}'
    run id_by_part "/dev/nvme0n1p5"
    [[ "$output" == "5" ]]
}

@test "dev_by_part: extracts disk from partition" {
    export MOCK_LSBLK_REVERSE_JSON='{"blockdevices":[{"kname":"sda3","type":"part","children":[{"kname":"sda","type":"disk"}]}]}'
    run dev_by_part "/dev/sda3"
    [[ "$output" == "/dev/sda" ]]
}

@test "part_by_name: with loaded scheme finds by label first" {
    _JSON_PARTITIONS=$(yq -o json '.partitions' "${FIXTURES_DIR}/partition.yml")
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[{"name":"/dev/sda","type":"disk","children":[{"name":"/dev/sda1","type":"part","label":"EFI"},{"name":"/dev/sda3","type":"part","label":"SYSTEM"},{"name":"/dev/sda4","type":"part","label":"HOME"}]}]}'
    run part_by_name "/dev/sda" "SYSTEM"
    [[ "$output" == "/dev/sda3" ]]
}

@test "part_label: returns label of a partition" {
    export MOCK_PART_LABEL="SYSTEM"
    run part_label "/dev/sda3"
    [[ "$output" == "SYSTEM" ]]
}


@test "part_by_label_on_device: finds SYSTEM on NVMe /dev/nvme0n1" {
    export MOCK_LSBLK_PARENT_JSON=$(cat "${FIXTURES_DIR}/lsblk-nvme.json")
    run part_by_label_on_device "/dev/nvme0n1" "SYSTEM"
    assert_success
    [[ "$output" == "/dev/nvme0n1p3" ]]
}

@test "part_by_label: finds partition by label on NVMe" {
    export MOCK_LSBLK_KNAME_JSON='{"blockdevices":[{"kname":null,"type":"disk","label":null},{"kname":"nvme0n1p3","type":"part","label":"SYSTEM"},{"kname":"nvme0n1p4","type":"part","label":"HOME"}]}'
    run part_by_label "SYSTEM"
    assert_output_contains "/dev/nvme0n1p3"
}

@test "dev_by_part: extracts NVMe disk from partition" {
    export MOCK_LSBLK_REVERSE_JSON='{"blockdevices":[{"kname":"nvme0n1p3","type":"part","children":[{"kname":"nvme0n1","type":"disk"}]}]}'
    run dev_by_part "/dev/nvme0n1p3"
    [[ "$output" == "/dev/nvme0n1" ]]
}

@test "part_by_name: with NVMe device uses nvme partition names" {
    _JSON_PARTITIONS=$(yq -o json '.partitions' "${FIXTURES_DIR}/partition.yml")
    export MOCK_LSBLK_PARENT_JSON=$(cat "${FIXTURES_DIR}/lsblk-nvme.json")
    run part_by_name "/dev/nvme0n1" "SYSTEM"
    [[ "$output" == "/dev/nvme0n1p3" ]]
}
