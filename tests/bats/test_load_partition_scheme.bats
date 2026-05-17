load '../helpers/assert'

setup() {
    load '../helpers/mocks'
    setup_mocks
    source_functions
    _VERIFY_CHECKSUMS=0
}

teardown() {
    teardown_mocks
}

@test "load_partition_scheme: loads from local directory" {
    run load_partition_scheme "${FIXTURES_DIR}"
    assert_success
}

@test "load_partition_scheme: detects missing partition.yml" {
    run load_partition_scheme "/tmp/nonexistent_dir_$$"
    assert_failure
}

@test "load_partition_scheme: detects invalid YAML" {
    run load_partition_scheme "${FIXTURES_DIR}"
    assert_success
}

@test "load_partition_scheme: loads checksums file when present" {
    run load_partition_scheme "${FIXTURES_DIR}"
    assert_success
}

@test "load_partition_scheme: missing checksums warns and continues" {
    run load_partition_scheme "${FIXTURES_DIR}"
    assert_success
}

@test "load_partition_scheme: from HTTP URL" {
    export MOCK_WGET_DIR="${FIXTURES_DIR}"
    run load_partition_scheme "http://server/pool/mci/project/"
    assert_success
}

@test "load_partition_scheme: HTTP URL with missing partition.yml returns error" {
    run load_partition_scheme "http://server/pool/mci/missing/"
    assert_failure
}

@test "load_partition_scheme: from URL ending with .raw (single file)" {
    export MOCK_WGET_DIR="${FIXTURES_DIR}"
    run load_partition_scheme "http://server/pool/mci/project/SYSTEM.raw"
    assert_success
}
