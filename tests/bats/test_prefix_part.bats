load '../helpers/assert'
load '../helpers/mocks'

setup() {
    setup_mocks
    source_functions
}

teardown() {
    teardown_mocks
}

@test "prefix_part: /dev/sda returns empty (ends with letter)" {
    run prefix_part "/dev/sda"
    [ "$output" = "" ]
}

@test "prefix_part: /dev/sdb returns empty" {
    run prefix_part "/dev/sdb"
    [ "$output" = "" ]
}

@test "prefix_part: /dev/vda returns empty" {
    run prefix_part "/dev/vda"
    [ "$output" = "" ]
}

@test "prefix_part: /dev/xvda returns empty" {
    run prefix_part "/dev/xvda"
    [ "$output" = "" ]
}

@test "prefix_part: /dev/hda returns empty" {
    run prefix_part "/dev/hda"
    [ "$output" = "" ]
}

@test "prefix_part: /dev/nvme0n1 returns p (ends with digit)" {
    run prefix_part "/dev/nvme0n1"
    [ "$output" = "p" ]
}

@test "prefix_part: /dev/nbd0 returns p" {
    run prefix_part "/dev/nbd0"
    [ "$output" = "p" ]
}

@test "prefix_part: /dev/mmcblk0 returns p" {
    run prefix_part "/dev/mmcblk0"
    [ "$output" = "p" ]
}

@test "prefix_part: /dev/loop0 returns p" {
    run prefix_part "/dev/loop0"
    [ "$output" = "p" ]
}

@test "prefix_part: /dev/sda1 returns p (ends with digit)" {
    run prefix_part "/dev/sda1"
    [ "$output" = "p" ]
}

@test "prefix_part: /dev/nvme1n1 returns p" {
    run prefix_part "/dev/nvme1n1"
    [ "$output" = "p" ]
}

@test "prefix_part: empty input returns empty" {
    run prefix_part ""
    [ "$output" = "" ]
}
