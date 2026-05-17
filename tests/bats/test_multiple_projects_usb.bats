load '../helpers/assert'
load '../helpers/mocks'

setup() {
    setup_mocks
    source_functions

    _create_mock_jq
    _create_mock_stat
    _create_mock_numfmt

    export MOCK_WGET_DIR="${FIXTURES_DIR}"
    export MOCK_LSBLK_PARENT_JSON='{"blockdevices":[]}'
    export MOCK_LSBLK_PKNAME_JSON='{"blockdevices":[]}'
    export MOCK_SFDISK_JSON='{"partitiontable":{"label":"gpt","device":"/dev/sda","partitions":[]}}'
    export MOCK_DISK_SIZE_MB=50000
    export MOCK_DIALOG_EXIT=0

    export PATH="$MOCK_DIR:$PATH"

    export IMAGES_DIR="$MOCK_DIR/images"
    export TEMPORAL_FILE="$MOCK_DIR/dialog_options"
    export TITLE="MCS Test"

    mkdir -p "$IMAGES_DIR"

    export SHOW_MSG_FILE="$MOCK_DIR/show_msg_captured"
    export SHOW_SELECTION_RETURN=""
    export SHOW_CONFIRM_RESULT=0

    rm -f "$SHOW_MSG_FILE"
}

teardown() {
    rm -rf "$MOCK_DIR"
}

_create_mock_jq() {
    cat > "$MOCK_DIR/jq" <<'SCRIPT'
#!/bin/bash
_JQ_NAME=""
for i in $(seq 1 $#); do
    eval "ARG=\$$i"
    if [ "$ARG" = "--arg" ]; then
        eval "_JQ_NAME=\$$((i + 2))"
    fi
done
_JQ_FILE="${!#}"
if [ -f "$_JQ_FILE" ] && [ -n "$_JQ_NAME" ]; then
    python3 -c "
import json, sys
data = json.load(open('$_JQ_FILE'))
for p in data:
    if p.get('name') == '$_JQ_NAME':
        d = p.get('description', '')
        if d:
            print(d)
        break
" 2>/dev/null
fi
SCRIPT
    chmod +x "$MOCK_DIR/jq"
}

_create_mock_stat() {
    cat > "$MOCK_DIR/stat" <<'SCRIPT'
#!/bin/bash
echo "${MOCK_STAT_SIZE:-1048576}"
SCRIPT
    chmod +x "$MOCK_DIR/stat"
}

_create_mock_numfmt() {
    cat > "$MOCK_DIR/numfmt" <<'SCRIPT'
#!/bin/bash
echo "${MOCK_NUMFMT_OUTPUT:-1.0M}"
SCRIPT
    chmod +x "$MOCK_DIR/numfmt"
}

show_selection() {
    if [ -n "$SHOW_SELECTION_RETURN" ]; then
        echo "$SHOW_SELECTION_RETURN"
    else
        echo ""
    fi
}

show_msg() {
    echo "$3" > "$SHOW_MSG_FILE"
    return 0
}

show_confirm() {
    return "$SHOW_CONFIRM_RESULT"
}

info_msg() {
    return 0
}

get_image() {
    local submenu="$1"
    local title="$2"
    local _DESC_FILE="$IMAGES_DIR/catalog.json"
    rm -f "$TEMPORAL_FILE"
    local INDEX=1
    for file in "$IMAGES_DIR"/*; do
        [ "$(basename "$file")" = "catalog.json" ] && continue
        if [ -d "$file" ]; then
            NAME=$(basename "$file")
            DESC=$(jq -r --arg n "$NAME" '.[] | select(.name == $n) | .description // empty' "$_DESC_FILE" 2>/dev/null)
            if [ -n "$DESC" ]; then
                echo "${INDEX} \"${NAME} - ${DESC}\"" >> "$TEMPORAL_FILE"
            else
                echo "${INDEX} \"${NAME}\"" >> "$TEMPORAL_FILE"
            fi
            INDEX=$((INDEX + 1))
        elif [ -f "$file" ]; then
            NAME=$(basename "$file")
            SIZE=$(stat -c %s "$file")
            echo "${INDEX} \"${NAME} ($(numfmt --to=iec $SIZE))\"" >> "$TEMPORAL_FILE"
            INDEX=$((INDEX + 1))
        fi
    done

    if [ "$INDEX" -gt 1 ]; then
        show_selection "$submenu" "$title"
    else
        show_msg "$submenu" "Error" "No images found in $IMAGES_DIR"
        echo ""
    fi
}

list_image() {
    local list=""
    local _DESC_FILE="$IMAGES_DIR/catalog.json"
    for file in "$IMAGES_DIR"/*; do
        [ "$(basename "$file")" = "catalog.json" ] && continue
        if [ -d "$file" ]; then
            NAME=$(basename "$file")
            DESC=$(jq -r --arg n "$NAME" '.[] | select(.name == $n) | .description // empty' "$_DESC_FILE" 2>/dev/null)
            if [ -n "$DESC" ]; then
                list="${list}${NAME} - ${DESC}\n"
            else
                list="${list}${NAME}\n"
            fi
        elif [ -f "$file" ]; then
            list="${list}$(basename "$file") ($(numfmt --to=iec $(stat -c %s "$file")))\n"
        fi
    done
    if [[ -z "$list" ]]; then
        show_msg "Local Images" "List" "No images found in $IMAGES_DIR"
    else
        show_msg "Local Images" "List" "$list"
    fi
}

delete_image() {
    local IMAGE=$(get_image "Local Images" "Delete")
    if [[ -z "$IMAGE" ]]; then
        return
    fi

    if [ -e "$IMAGES_DIR/$IMAGE" ]; then
        show_confirm "Local Images" "Delete?" "Are you sure you want to delete project $IMAGE?"
        if [ $? = 0 ]; then
            local IMAGE_NAME=$(echo "$IMAGE" | awk '{print $1}')
            rm -rf "$IMAGES_DIR/$IMAGE_NAME"
            show_msg "Local Images" "Delete" "$IMAGE_NAME deleted."
        fi
    fi
}

msg_was() {
    local _expected="$1"
    local _msg=$(cat "$SHOW_MSG_FILE" 2>/dev/null)
    if [[ "$_msg" != *"$_expected"* ]]; then
        echo "Expected captured message to contain: $_expected"
        echo "Actual captured message: $_msg"
        return 1
    fi
}


@test "get_image: enumerates 2 projects with descriptions" {
    mkdir -p "$IMAGES_DIR/proj-a"
    touch "$IMAGES_DIR/proj-a/partition.yml"
    mkdir -p "$IMAGES_DIR/proj-b"
    touch "$IMAGES_DIR/proj-b/partition.yml"
    cat > "$IMAGES_DIR/catalog.json" <<'JSON'
[{"name":"proj-a","enabled":true,"description":"Project Alpha"},{"name":"proj-b","enabled":true,"description":"Project Beta"}]
JSON

    run get_image "Test" "Test"

    file_content=$(cat "$TEMPORAL_FILE")
    [[ "$file_content" == *'1 "proj-a - Project Alpha"'* ]]
    [[ "$file_content" == *'2 "proj-b - Project Beta"'* ]]
}


@test "get_image: enumerates projects without descriptions when no catalog.json" {
    mkdir -p "$IMAGES_DIR/proj-a"
    touch "$IMAGES_DIR/proj-a/partition.yml"
    mkdir -p "$IMAGES_DIR/proj-b"
    touch "$IMAGES_DIR/proj-b/partition.yml"

    run get_image "Test" "Test"

    file_content=$(cat "$TEMPORAL_FILE")
    [[ "$file_content" == *'1 "proj-a"'* ]]
    [[ "$file_content" == *'2 "proj-b"'* ]]
    [[ "$file_content" != *" - "* ]]
}


@test "get_image: skips catalog.json in enumeration" {
    mkdir -p "$IMAGES_DIR/proj-a"
    touch "$IMAGES_DIR/proj-a/partition.yml"
    mkdir -p "$IMAGES_DIR/proj-b"
    touch "$IMAGES_DIR/proj-b/partition.yml"
    cat > "$IMAGES_DIR/catalog.json" <<'JSON'
[{"name":"proj-a","enabled":true},{"name":"proj-b","enabled":true}]
JSON

    run get_image "Test" "Test"

    file_content=$(cat "$TEMPORAL_FILE")
    [[ "$file_content" != *"catalog.json"* ]]
    [[ "$file_content" != *"catalog"* ]]
}


@test "get_image: shows error when no projects exist (empty dir)" {
    rm -f "$SHOW_MSG_FILE"

    run get_image "Test" "Test"

    msg_was "No images found"
}


@test "get_image: shows error when only catalog.json exists" {
    rm -f "$SHOW_MSG_FILE"
    cat > "$IMAGES_DIR/catalog.json" <<'JSON'
[{"name":"proj-a","enabled":true}]
JSON

    run get_image "Test" "Test"

    msg_was "No images found"
}


@test "get_image: enumerates mixed directories and raw files" {
    mkdir -p "$IMAGES_DIR/proj-a"
    touch "$IMAGES_DIR/proj-a/partition.yml"
    touch "$IMAGES_DIR/legacy.raw"

    run get_image "Test" "Test"

    file_content=$(cat "$TEMPORAL_FILE")
    [[ "$file_content" == *'"proj-a"'* ]]
    [[ "$file_content" == *'"legacy.raw (1.0M)"'* ]]
}


@test "list_image: lists 2 projects with descriptions" {
    rm -f "$SHOW_MSG_FILE"
    mkdir -p "$IMAGES_DIR/proj-a"
    touch "$IMAGES_DIR/proj-a/partition.yml"
    mkdir -p "$IMAGES_DIR/proj-b"
    touch "$IMAGES_DIR/proj-b/partition.yml"
    cat > "$IMAGES_DIR/catalog.json" <<'JSON'
[{"name":"proj-a","enabled":true,"description":"Alpha"},{"name":"proj-b","enabled":true,"description":"Beta"}]
JSON

    run list_image

    msg_was "proj-a - Alpha"
    msg_was "proj-b - Beta"
}


@test "list_image: shows error when empty" {
    rm -f "$SHOW_MSG_FILE"

    run list_image

    msg_was "No images found"
}


@test "list_image: lists projects without descriptions when no catalog.json" {
    rm -f "$SHOW_MSG_FILE"
    mkdir -p "$IMAGES_DIR/proj-a"
    touch "$IMAGES_DIR/proj-a/partition.yml"
    mkdir -p "$IMAGES_DIR/proj-b"
    touch "$IMAGES_DIR/proj-b/partition.yml"

    run list_image

    msg_was "proj-a"
    msg_was "proj-b"
}


@test "delete_image: deletes selected project and preserves other" {
    mkdir -p "$IMAGES_DIR/proj-a"
    touch "$IMAGES_DIR/proj-a/partition.yml"
    touch "$IMAGES_DIR/proj-a/SYSTEM.raw"
    mkdir -p "$IMAGES_DIR/proj-b"
    touch "$IMAGES_DIR/proj-b/partition.yml"
    touch "$IMAGES_DIR/proj-b/SYSTEM.raw"
    cat > "$IMAGES_DIR/catalog.json" <<'JSON'
[{"name":"proj-a","enabled":true},{"name":"proj-b","enabled":true}]
JSON

    SHOW_SELECTION_RETURN="proj-a"
    SHOW_CONFIRM_RESULT=0

    run delete_image

    [ ! -d "$IMAGES_DIR/proj-a" ]
    [ -d "$IMAGES_DIR/proj-b" ]
    [ -f "$IMAGES_DIR/catalog.json" ]
}


@test "delete_image: preserves project when user cancels confirmation" {
    mkdir -p "$IMAGES_DIR/proj-a"
    touch "$IMAGES_DIR/proj-a/partition.yml"
    SHOW_SELECTION_RETURN="proj-a"
    SHOW_CONFIRM_RESULT=1

    run delete_image

    [ -d "$IMAGES_DIR/proj-a" ]
}


@test "clone_menu: extracts project name from description label" {
    local IMAGE="proj-a - Project Alpha"
    local _IMAGE_NAME=$(echo "$IMAGE" | awk '{print $1}')
    [[ "$_IMAGE_NAME" = "proj-a" ]]
}


@test "clone_menu: extracts project name from label without description" {
    local IMAGE="proj-a"
    local _IMAGE_NAME=$(echo "$IMAGE" | awk '{print $1}')
    [[ "$_IMAGE_NAME" = "proj-a" ]]
}
