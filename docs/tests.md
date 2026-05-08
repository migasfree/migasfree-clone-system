# Unit Testing with bats-core

MCS uses [bats-core](https://github.com/bats-core/bats-core) for unit testing shell functions.

## Installation

### On Debian/Ubuntu

```bash
sudo apt install -y bats jq
# yq (Go version) for YAML parsing
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

### On macOS

```bash
brew install bats-core jq yq
```

### From GitHub (any Linux)

```bash
git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
sudo /tmp/bats-core/install.sh /usr/local
rm -rf /tmp/bats-core
```

### Inside the MCS Docker build container

```bash
apk add bats jq yq
```

## Running Tests

### All tests

```bash
make test
```

### A specific test file

```bash
bats tests/bats/test_prefix_part.bats
```

### Verbose output

```bash
bats -T tests/bats/test_prefix_part.bats
```

### Test with TAP formatter (CI)

```bash
bats --formatter tap tests/bats/
```

## Test Structure

```text
tests/
├── bats/                          # Test files (.bats)
│   ├── test_prefix_part.bats      # prefix_part() function
│   ├── test_part_by_label.bats    # Label/disk queries
│   ├── test_nbd_first_free.bats   # NBD device allocation
│   ├── test_max_home_size.bats    # HOME size calculation
│   ├── test_load_partition_scheme.bats  # partition.yml loading
│   ├── test_verify_checksum.bats  # SHA-256 verification
│   ├── test_make_fstab.bats       # fstab generation
│   └── test_clone_HD.bats         # clone_HD full-flow tests
├── helpers/
│   ├── mocks.bash                 # Mock system binaries (lsblk, sfdisk, wget, etc.)
│   └── assert.bash                # Custom assertions
└── fixtures/
    ├── partition.yml              # Standard partition scheme
    ├── partition_minimal.yml      # Scheme without HOME
    ├── partition_invalid.yml      # Invalid YAML
    ├── checksums.sha256           # Checksums file
    ├── projects.json              # Project index
    ├── SYSTEM.raw                 # 1MB dummy image
    ├── HOME.raw                   # 1MB dummy image
    ├── lsblk-sda.json             # Mock lsblk output (SATA)
    ├── lsblk-nvme.json            # Mock lsblk output (NVMe)
    └── sfdisk-sda.json            # Mock sfdisk output
```

## How Tests Work

### Pure functions (no system deps)

Functions like `prefix_part` are self-contained. The test sources `functions` directly:

```bash
setup() {
    . "${BATS_TEST_DIRNAME}/../defaults/overlay/usr/share/mcs/functions"
}

@test "prefix_part: /dev/nvme0n1 returns p" {
    run prefix_part "/dev/nvme0n1"
    [ "$output" = "p" ]
}
```

### Functions with system dependencies

Functions that call `lsblk`, `wget`, `sfdisk`, etc. use the mock infrastructure. The `setup_mocks` function creates fake executables in a temporary `$MOCK_DIR` that is prepended to `$PATH`:

```bash
setup() {
    load '../helpers/mocks'
    setup_mocks
    source_functions
    export MOCK_LSBLK_JSON=$(cat "${FIXTURES_DIR}/lsblk-sda.json")
}

@test "part_by_label: finds SYSTEM on /dev/sda" {
    run part_by_label "SYSTEM"
    [ "$output" == "/dev/sda3" ]
}
```

### Environment variables for mock control

| Variable | Controls | Used by |
| --- | --- | --- |
| `MOCK_LSBLK_JSON` | `lsblk -J` JSON output | `part_by_label`, `disk_by_label`, `dev_by_part` |
| `MOCK_LSBLK_KNAME_JSON` | `lsblk -J -o KNAME,...` output | `dev_by_part` |
| `MOCK_PART_LABEL` | `lsblk -n -o LABEL` output | `part_label` |
| `MOCK_SFDISK_JSON` | `sfdisk -J` JSON output | `check_home_viability` |
| `MOCK_DISK_SIZE_MB` | `blockdev --getsize64` output | `get_megas_device`, `max_home_size` |
| `MOCK_WGET_DIR` | Directory for `wget` to serve files from | `load_partition_scheme`, `clone_HD` |
| `MOCK_NBD_DEVICE` | Device path returned by `qemu-nbd` | `connect_HD` |
| `MOCK_NBD_COUNT` | Number of NBD devices to simulate | `nbd-first-free` |

### Assertions

Custom assertions in `tests/helpers/assert.bash`:

| Function | Purpose |
| --- | --- |
| `assert_success` | Status must be 0 |
| `assert_failure` | Status must be non-zero |
| `assert_output_eq "text"` | Output must exactly match |
| `assert_output_contains "text"` | Output must contain substring |
| `assert_output_not_contains "text"` | Output must NOT contain substring |
| `assert_log_contains "/path/to/log" "text"` | Log file must contain text |
| `assert_file_exists "/path"` | File must exist |
| `assert_dir_exists "/path"` | Directory must exist |

## Adding New Tests

1. Create a `.bats` file in `tests/bats/`
2. `load '../helpers/assert'` for assertions
3. For system-dependent tests, `load '../helpers/mocks'` + `setup_mocks`
4. Use `source_functions` to initialize globals and disable checksum verification
5. Set mock environment variables to control fake system binaries
6. Run with `bats tests/bats/your_test.bats`

## Test Coverage

| Area | Tests | Status |
| --- | --- | --- |
| `prefix_part` | 12 | ✅ |
| `part_by_label`, `disk_by_label`, `part_by_id`, `id_by_part`, `dev_by_part`, `part_by_name`, `part_label` | 16 | ✅ |
| `nbd-first-free` | 4 | ✅ |
| `max_home_size` | 4 | ✅ |
| `load_partition_scheme` | 8 | ✅ |
| `verify_file_checksum`, `verify_partition_checksum` | 6 | ✅ |
| `make_fstab` | 9 | ✅ |
| `clone_HD` | 7 | ✅ |
| **Total** | **66** | ✅ |
