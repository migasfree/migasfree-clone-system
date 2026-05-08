load '../helpers/assert'

setup() {
    load '../helpers/mocks'
    setup_mocks
    source_functions
    _JSON_PARTITIONS=$(yq -o json '.partitions' "${FIXTURES_DIR}/partition.yml")
}

teardown() {
    teardown_mocks
}

@test "max_home_size: disk larger than scheme, returns configured HOME size" {
    export MOCK_DISK_SIZE_MB=250000
    run max_home_size "/dev/sda"
    assert_success
    [[ "$output" == "0" ]]
}

@test "max_home_size: disk exactly fits partitions" {
    export MOCK_DISK_SIZE_MB=20993
    _JSON_PARTITIONS=$(yq -o json '.partitions' "${FIXTURES_DIR}/partition_minimal.yml")
    run max_home_size "/dev/sda"
    assert_success
}

@test "max_home_size: disk smaller than reserved, returns 0" {
    export MOCK_DISK_SIZE_MB=512
    run max_home_size "/dev/sda"
    assert_success
}

@test "max_home_size: no HOME in scheme returns 0" {
    _JSON_PARTITIONS='[]'
    run max_home_size "/dev/sda"
    assert_success
    [ "$output" = "0" ]
}
