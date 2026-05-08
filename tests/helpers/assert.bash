assert_output_contains() {
    local _expected="$1"
    if [[ "$output" != *"$_expected"* ]]; then
        echo "Expected output to contain: $_expected"
        echo "Actual output: $output"
        return 1
    fi
}

assert_output_not_contains() {
    local _unexpected="$1"
    if [[ "$output" == *"$_unexpected"* ]]; then
        echo "Expected output NOT to contain: $_unexpected"
        echo "Actual output: $output"
        return 1
    fi
}

assert_success() {
    if [ "$status" -ne 0 ]; then
        echo "Expected success (status 0), got status $status"
        echo "Output: $output"
        return 1
    fi
}

assert_failure() {
    if [ "$status" -eq 0 ]; then
        echo "Expected failure (non-zero status), got status 0"
        echo "Output: $output"
        return 1
    fi
}

assert_output_eq() {
    if [ "$output" != "$1" ]; then
        echo "Expected: $1"
        echo "Actual:   $output"
        return 1
    fi
}

assert_log_contains() {
    local _logfile="$1"
    local _expected="$2"
    if ! grep -q "$_expected" "$_logfile" 2>/dev/null; then
        echo "Expected log to contain: $_expected"
        echo "Log file: $_logfile"
        [ -f "$_logfile" ] && cat "$_logfile"
        return 1
    fi
}

assert_file_exists() {
    if [ ! -f "$1" ]; then
        echo "Expected file to exist: $1"
        return 1
    fi
}

assert_dir_exists() {
    if [ ! -d "$1" ]; then
        echo "Expected directory to exist: $1"
        return 1
    fi
}
