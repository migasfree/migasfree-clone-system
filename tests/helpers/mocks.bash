BATS_PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME" && while [ ! -f "Makefile" ] && [ "$(pwd)" != "/" ]; do cd ..; done && pwd)"

setup_mocks() {
    export MOCK_DIR=$(mktemp -d)
    export FUNCTIONS_FILE="${BATS_PROJECT_ROOT}/defaults/overlay/usr/share/mcs/functions"
    export FIXTURES_DIR="${BATS_PROJECT_ROOT}/tests/fixtures"

    _create_mock_lsblk
    _create_mock_sfdisk
    _create_mock_blockdev
    _create_mock_wget
    _create_mock_qemu_nbd
    _create_mock_partprobe
    _create_mock_partx
    _create_mock_udevadm
    _create_mock_shasum
    _create_mock_yq
    _create_mock_blkid
    _create_mock_mkfs
    _create_mock_qemu_img
    _create_mock_pv
    _create_mock_dd
    _create_mock_sync
    _create_mock_lsmod
    _create_mock_modprobe
    _create_mock_mount
    _create_mock_chroot
    _create_mock_sleep
    _create_mock_tee
    _create_mock_e2fsprogs
    _create_mock_dialog

    export PATH="$MOCK_DIR:$PATH"
}

teardown_mocks() {
    rm -rf "$MOCK_DIR"
}

_create_mock_lsblk() {
    cat > "$MOCK_DIR/lsblk" <<'SCRIPT'
#!/bin/bash
ALL_ARGS="$*"
if echo "$ALL_ARGS" | grep -q -- "-s"; then
    echo "${MOCK_LSBLK_REVERSE_JSON}"
elif echo "$ALL_ARGS" | grep -q -- "-p"; then
    echo "${MOCK_LSBLK_PARENT_JSON}"
elif echo "$ALL_ARGS" | grep -q "PKNAME"; then
    echo "${MOCK_LSBLK_PKNAME_JSON}"
elif echo "$ALL_ARGS" | grep -q "KNAME"; then
    echo "${MOCK_LSBLK_KNAME_JSON}"
elif echo "$ALL_ARGS" | grep -q -- "-n"; then
    echo "${MOCK_PART_LABEL:-}"
else
    echo '{"blockdevices":[]}'
fi
SCRIPT
    chmod +x "$MOCK_DIR/lsblk"
}

_create_mock_sfdisk() {
    cat > "$MOCK_DIR/sfdisk" <<'SCRIPT'
#!/bin/bash
if [ "$1" = "-J" ]; then
    echo "${MOCK_SFDISK_JSON:-{\"partitiontable\":{\"label\":\"gpt\",\"device\":\"/dev/sda\",\"partitions\":[]}}}"
else
    echo ""
fi
SCRIPT
    chmod +x "$MOCK_DIR/sfdisk"
}

_create_mock_blockdev() {
    cat > "$MOCK_DIR/blockdev" <<'SCRIPT'
#!/bin/bash
echo $(( ${MOCK_DISK_SIZE_MB:-50000} * 1024 * 1024 ))
SCRIPT
    chmod +x "$MOCK_DIR/blockdev"
}

_create_mock_wget() {
    cat > "$MOCK_DIR/wget" <<'SCRIPT'
#!/bin/bash
outfile=""
idx=1
for arg in "$@"; do
    if [ "$arg" = "-O" ]; then
        next_idx=$((idx + 1))
        eval outfile="\${$next_idx}"
    fi
    idx=$((idx + 1))
done
case "$*" in
    *partition.yml*)
        if [ -n "$outfile" ] && [ -f "${MOCK_WGET_DIR}/partition.yml" ]; then
            cp "${MOCK_WGET_DIR}/partition.yml" "$outfile" 2>/dev/null
            exit 0
        fi
        exit 1
        ;;
    *checksums.sha256*)
        [ -f "${MOCK_WGET_DIR}/checksums.sha256" ]
        exit $?
        ;;
    *.raw*)
        exit 0
        ;;
    *catalog.json*)
        [ -f "${MOCK_WGET_DIR}/catalog.json" ]
        exit $?
        ;;
    *)
        exit 1
        ;;
esac
SCRIPT
    chmod +x "$MOCK_DIR/wget"
}

_create_mock_qemu_nbd() {
    cat > "$MOCK_DIR/qemu-nbd" <<'SCRIPT'
#!/bin/bash
[ "$1" = "-d" ] && exit 0
echo "${MOCK_NBD_DEVICE:-/dev/nbd0}"
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/qemu-nbd"
}

_create_mock_partprobe() {
    echo '#!/bin/bash' > "$MOCK_DIR/partprobe"
    chmod +x "$MOCK_DIR/partprobe"
}

_create_mock_partx() {
    echo '#!/bin/bash' > "$MOCK_DIR/partx"
    chmod +x "$MOCK_DIR/partx"
}

_create_mock_udevadm() {
    echo '#!/bin/bash' > "$MOCK_DIR/udevadm"
    chmod +x "$MOCK_DIR/udevadm"
}

_create_mock_shasum() {
    cat > "$MOCK_DIR/sha256sum" <<'SCRIPT'
#!/bin/bash
echo "${MOCK_SHA256:-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855}"
SCRIPT
    chmod +x "$MOCK_DIR/sha256sum"
}

_create_mock_yq() {
    cat > "$MOCK_DIR/yq" <<'SCRIPT'
#!/usr/bin/python3
import yaml, json, sys

query = ""
exit_code = 0

for arg in sys.argv[1:-1]:
    if not arg.startswith('-'):
        query = arg
        break
if not query and len(sys.argv) > 1 and not sys.argv[1].startswith('-'):
    query = sys.argv[1]

try:
    filepath = sys.argv[-1]
    with open(filepath, 'r') as f:
        data = yaml.safe_load(f)
except Exception:
    sys.exit(1)

try:
    if query == ".partitions":
        if isinstance(data, dict) and 'partitions' in data and data['partitions'] is not None:
            print(json.dumps(data['partitions']))
        else:
            print("null")
            exit_code = 1
    elif query == ".variables":
        if isinstance(data, dict) and 'variables' in data and data['variables'] is not None:
            pass
        else:
            print("null")
            exit_code = 1
    elif query == ".variables | keys | .[]":
        if isinstance(data, dict) and 'variables' in data and isinstance(data['variables'], dict):
            for k in data['variables'].keys():
                print(k)
        else:
            exit_code = 1
    elif query.startswith(".variables."):
        parts = [p for p in query.split('.') if p]
        val = data
        for p in parts:
            if isinstance(val, dict) and p in val:
                val = val[p]
            else:
                val = None
                break
        if val is not None:
            if isinstance(val, bool):
                print(str(val).lower())
            else:
                print(val)
        else:
            print("null")
            exit_code = 1
    else:
        if isinstance(data, dict) and 'partitions' in data:
            print(json.dumps(data['partitions']))
        else:
            print("null")
            exit_code = 1
except Exception:
    print("null")
    exit_code = 1

sys.exit(exit_code)
SCRIPT
    chmod +x "$MOCK_DIR/yq"
}

_create_mock_blkid() {
    echo '#!/bin/bash
echo "deadbeef-1234-5678-9abc-def012345678"' > "$MOCK_DIR/blkid"
    chmod +x "$MOCK_DIR/blkid"
}

_create_mock_mkfs() {
    for cmd in mkfs.ext4 mkfs.fat mkswap; do
        echo '#!/bin/bash' > "$MOCK_DIR/$cmd"
        chmod +x "$MOCK_DIR/$cmd"
    done
}

_create_mock_qemu_img() {
    echo '#!/bin/bash' > "$MOCK_DIR/qemu-img"
    chmod +x "$MOCK_DIR/qemu-img"
}

_create_mock_pv() {
    cat > "$MOCK_DIR/pv" <<'SCRIPT'
#!/bin/bash
# Discard all data — pv is just a progress meter, no effect on data flow
# Strip flags (like -f) and pass only file arguments to cat, or just discard stdin
for arg in "$@"; do
    case "$arg" in
        -*) continue ;;
        *) cat "$arg" > /dev/null 2>/dev/null; exit 0 ;;
    esac
done
# No file arguments — read from stdin (piped data)
cat > /dev/null
SCRIPT
    chmod +x "$MOCK_DIR/pv"
}

_create_mock_dd() {
    echo '#!/bin/bash' > "$MOCK_DIR/dd"
    chmod +x "$MOCK_DIR/dd"
}

_create_mock_sync() {
    echo '#!/bin/bash' > "$MOCK_DIR/sync"
    chmod +x "$MOCK_DIR/sync"
}

_create_mock_lsmod() {
    echo '#!/bin/bash
echo "nbd                    40448  2"' > "$MOCK_DIR/lsmod"
    chmod +x "$MOCK_DIR/lsmod"
}

_create_mock_modprobe() {
    echo '#!/bin/bash' > "$MOCK_DIR/modprobe"
    chmod +x "$MOCK_DIR/modprobe"
}

_create_mock_mount() {
    echo '#!/bin/bash' > "$MOCK_DIR/mount"
    chmod +x "$MOCK_DIR/mount"
}

_create_mock_chroot() {
    cat > "$MOCK_DIR/chroot" <<'SCRIPT'
#!/bin/bash
SCRIPT
    chmod +x "$MOCK_DIR/chroot"
}

_create_mock_sleep() {
    echo '#!/bin/bash' > "$MOCK_DIR/sleep"
    chmod +x "$MOCK_DIR/sleep"
}

_create_mock_tee() {
    cat > "$MOCK_DIR/tee" <<'SCRIPT'
#!/bin/bash
cat
exit 0
SCRIPT
    chmod +x "$MOCK_DIR/tee"
}

_create_mock_e2fsprogs() {
    for cmd in e2fsck resize2fs; do
        echo '#!/bin/bash' > "$MOCK_DIR/$cmd"
        chmod +x "$MOCK_DIR/$cmd"
    done
}

_create_mock_dialog() {
    echo '#!/bin/bash
exit 0' > "$MOCK_DIR/dialog"
    chmod +x "$MOCK_DIR/dialog"
}

setup_nbd_sys_class() {
    local _COUNT="${1:-16}"
    mkdir -p "$MOCK_DIR/sys/class/block"
    for i in $(seq 0 $_COUNT); do
        mkdir -p "$MOCK_DIR/sys/class/block/nbd$i"
        echo "0" > "$MOCK_DIR/sys/class/block/nbd$i/size"
    done
}

mock_nbd_busy() {
    local _N="${1:-0}"
    echo "1" > "$MOCK_DIR/sys/class/block/nbd$_N/size"
}

source_functions() {
    . "${BATS_PROJECT_ROOT}/defaults/overlay/usr/share/mcs/functions"
    export MCS_LOG_FILE="/dev/null"
    export _VERIFY_CHECKSUMS=0
}
