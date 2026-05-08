load '../helpers/assert'

setup() {
    load '../helpers/mocks'
    setup_mocks
    source_functions
    setup_nbd_sys_class 15
    export MCS_SYSFS_PATH="${MOCK_DIR}/sys/class/block"
}

teardown() {
    teardown_mocks
}

@test "nbd-first-free: returns /dev/nbd0 when all free" {
    run nbd-first-free
    assert_success
    [[ "$output" == "/dev/nbd0" ]]
}

@test "nbd-first-free: skips busy devices, returns first free" {
    mock_nbd_busy 0
    mock_nbd_busy 1
    run nbd-first-free
    assert_success
    # Glob sorts alphabetically: nbd0,nbd1,nbd10,nbd11,...nbd2,nbd3,...
    # So nbd10 is found before nbd2
    [[ "$output" == "/dev/nbd10" ]]
}

@test "nbd-first-free: returns error when all NBDs busy" {
    for i in $(seq 0 15); do
        mock_nbd_busy $i
    done
    run nbd-first-free
    assert_failure
}

@test "nbd-first-free: no NBD devices returns error" {
    rm -rf "$MOCK_DIR/sys/class/block/nbd"*
    run nbd-first-free
    assert_failure
}
