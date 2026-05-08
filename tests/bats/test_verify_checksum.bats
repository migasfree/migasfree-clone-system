load '../helpers/assert'

setup() {
    load '../helpers/mocks'
    setup_mocks
    source_functions
    _VERIFY_CHECKSUMS=1
    _CHECKSUMS_FILE="${FIXTURES_DIR}/checksums.sha256"
}

teardown() {
    teardown_mocks
}

@test "verify_file_checksum: returns 0 when verification disabled" {
    _VERIFY_CHECKSUMS=0
    run verify_file_checksum "${FIXTURES_DIR}/SYSTEM.raw" "SYSTEM.raw"
    assert_success
}

@test "verify_file_checksum: returns 0 when checksums file not set" {
    _CHECKSUMS_FILE=""
    run verify_file_checksum "${FIXTURES_DIR}/SYSTEM.raw" "SYSTEM.raw"
    assert_success
}

@test "verify_file_checksum: returns 0 when name not in checksums file" {
    run verify_file_checksum "${FIXTURES_DIR}/SYSTEM.raw" "UNKNOWN.raw"
    assert_success
}

@test "verify_file_checksum: detects checksum mismatch" {
    export MOCK_SHA256="0000000000000000000000000000000000000000000000000000000000000000"
    echo "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 1048576 SYSTEM.raw" > /tmp/test_bad_checksum.sha256
    _CHECKSUMS_FILE="/tmp/test_bad_checksum.sha256"
    run verify_file_checksum "${FIXTURES_DIR}/SYSTEM.raw" "SYSTEM.raw"
    assert_failure
    rm -f /tmp/test_bad_checksum.sha256
}

@test "verify_partition_checksum: returns 0 when verification disabled" {
    _VERIFY_CHECKSUMS=0
    run verify_partition_checksum "/dev/null" "SYSTEM"
    assert_success
}

@test "verify_partition_checksum: returns 0 when no checksums file" {
    _CHECKSUMS_FILE=""
    run verify_partition_checksum "/dev/null" "SYSTEM"
    assert_success
}
