#!/bin/bash
set -o pipefail

. /usr/share/mcs/functions

TAG=$(cat /usr/share/mcs/VERSION)
MOUNT="/mcsdata"
CONFIG_FILE="$MOUNT/config.yml"
IMAGES_DIR="$MOUNT/images"
TEMPORAL_FILE="/tmp/dialog_options"


show_selection() {
    local backtitle="$1"
    local title="$2"
    SELECTION=$(dialog --backtitle "$TITLE > $backtitle" --title "$title" --menu "" 15 50 4 --file $TEMPORAL_FILE 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
        echo "$(sed -n ${SELECTION}p $TEMPORAL_FILE)" | awk -F'"' '{print $2}'
    else
        echo ""
    fi
}


show_confirm() {
    local backtitle="$1"
    local title="$2"
    local prompt="$3"
    local default="$4"
    if [ "$default" = "yes" ]; then
        dialog --backtitle "$TITLE > $backtitle" --title "$title" --yesno "$prompt" 12 50
    else
        dialog --backtitle "$TITLE > $backtitle" --title "$title" --defaultno --yesno "$prompt" 12 50
    fi
}

show_msg() {
    local backtitle="$1"
    local title="$2"
    local prompt="$3"
    dialog --backtitle "$TITLE > $backtitle" --title "$title" --msgbox "$prompt" 12 50
}

info_msg() {
    local backtitle="$1"
    local title="$2"
    local prompt="$3"
    dialog --backtitle "$TITLE > $backtitle" --title "$title" --infobox "$prompt" 12 50
}

find_disk_by_label() {
    local _LABEL="$1"
    _KNAME=$(lsblk -J -o KNAME,TYPE,LABEL 2>/dev/null | jq -r --arg l "$_LABEL" '.. | objects | select(.type == "disk" and .label == $l) | .kname' | head -n 1)
    if [ -z "$_KNAME" ] || [ "$_KNAME" = "null" ]; then
        return 1
    else
        echo "/dev/${_KNAME}"
    fi
}

find_partition_by_label() {
    local _LABEL="$1"
    _KNAME=$(lsblk -J -o KNAME,TYPE,LABEL 2>/dev/null | jq -r --arg l "$_LABEL" '.. | objects | select(.type == "part" and .label == $l) | .kname' | head -n 1)
    if [ -z "$_KNAME" ] || [ "$_KNAME" = "null" ]; then
        return 1
    else
        echo "/dev/${_KNAME}"
    fi
}

# LOAD SETTINGS
# =============
SERVER_URL=$(yq '.settings.server' < ${CONFIG_FILE})
SERVER_IP=$(yq '.settings.server_ip' < ${CONFIG_FILE})
KEYMAP=$(yq '.settings.keymap' < ${CONFIG_FILE})
VERIFY_CHECKSUMS=$(yq '.settings.verify_checksums // true' < ${CONFIG_FILE})
_VERIFY_CHECKSUMS=$VERIFY_CHECKSUMS
TITLE="Migasfree Clone System ${TAG}"


update_hosts() {
    # Remove old entry if exists
    sed -i "/ ${SERVER_URL}$/d" /etc/hosts
    # Add new entry if IP is set
    if [[ -n "$SERVER_IP" && -n "$SERVER_URL" ]]; then
        printf '%s %s\n' "${SERVER_IP}" "${SERVER_URL}" >> /etc/hosts
    fi
}

update_hosts


if [ -f /mcsdata/firstrun ]
then
    clear
    resize_MCS_DATA
    rm  /mcsdata/firstrun
    _SIZE=$(df -h $(blkid -o device -t LABEL="MCS_DATA") | awk 'NR > 1 {print $2}')
    clear
    show_msg "" "First run" "Completed.\nCongratulation! you have $_SIZE for images."
    clear
fi


if ! [ -f ${CONFIG_FILE} ]; then
    cp /usr/share/mcs/config.yml ${CONFIG_FILE}
fi

if ! [ -f ${MOUNT}/images ]; then
    mkdir ${MOUNT}/images
fi





# Crear directorios necesarios
mkdir -p "$IMAGES_DIR"



main_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "$TITLE" \
                      --title "Main Menu" \
                      --menu "" 15 55 5 \
                      1 "Network Clone" \
                      2 "Local Clone" \
                      3 "Local Images" \
                      4 "Settings" \
                      5 "Poweroff" \
                      3>&1 1>&2 2>&3)

        case $CHOICE in
            1) network_clone_menu ;;
            2) clone_menu ;;
            3) images_menu ;;
            4) settings_menu ;;
            5) off ;;
            *) quit ;;
        esac
    done
}


# CLONE
# =====

fetch_remote_projects() {
    local _URL="$1"

    wget -q --timeout=15 -O - "${_URL}projects.json" 2>/dev/null | jq -r '.[] | select(.enabled != false) | if .description then "\(.name) - \(.description)" else .name end' 2>/dev/null | awk '{print NR " \"" $0 "\""}'
}


get_image() {
    local submenu="$1"
    local title="$2"
    local _DESC_FILE="$IMAGES_DIR/projects.json"
    rm -f "$TEMPORAL_FILE"
    local INDEX=1
    for file in "$IMAGES_DIR"/*; do
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

get_disk() {
    rm -f "$TEMPORAL_FILE"
    local INDEX=1
    local MCS_DISK=$(disk_by_label "MCS_ROOT")
    local lsblk_json=$(lsblk -J -nd --output NAME,SIZE,TYPE 2>/dev/null)
    local lsblk_output=$(echo "$lsblk_json" | jq -r '.. | objects | select(.type == "disk") | "\(.name)|\(.size)"' 2>/dev/null)

    while IFS='|' read -r NAME SIZE; do
        if [ -n "$NAME" ]; then
            # Excluding floppy, mcs usb, or disk size=0B
            if ! [[ "${NAME}" = "fd0" || "/dev/${NAME}" = "${MCS_DISK}" || "${SIZE}" = "0B" ]]; then
                echo "${INDEX} \"${NAME} ${SIZE}\"" >> "$TEMPORAL_FILE"
                INDEX=$((INDEX + 1))
            fi
        fi
    done <<< "$lsblk_output"

    if [ "$INDEX" -eq 1 ]; then
        show_msg "Clone" "Error" "No suitable destination disks found!"
        echo ""
    else
        show_selection "Clone" "Destination disk"
    fi
}


get_keymap() {
    rm -f "$TEMPORAL_FILE"
    local INDEX=1
    local _output=$(ls /usr/share/keymaps/xkb/*.map.gz)
    while IFS=' ' read -r NAME; do
            echo "${INDEX} \"$(basename ${NAME%.map.gz})\"" >> "$TEMPORAL_FILE"
            INDEX=$((INDEX + 1))
    done <<< "$_output"

    if [ "$INDEX" -gt 1 ]; then
        show_selection "Settings" "Keymap"
    else
        show_msg "Settings" "Error" "No keymaps found in /usr/share/keymaps/"
        echo ""
    fi
}


clone_menu(){
    if [ -z "$(ls -A "$IMAGES_DIR")" ]; then
        show_msg "Local Clone" "Error" "No images found in $IMAGES_DIR.\nPlease download one first."
        return
    fi
    IMAGE=$(get_image "Local Clone" "Source image")
    if [[ -z "$IMAGE" ]]; then
       return
    fi
    DISK=$(get_disk)
    if [[ -z "$DISK" ]]; then
       return
    fi

    local _IMAGE_NAME=$(echo "$IMAGE" | awk '{print $1}')
    local _DISK_DEV=$(echo "$DISK" | awk '{print $1}')
    local _PRESERVE_HOME="false"

    load_partition_scheme "$IMAGES_DIR/$_IMAGE_NAME"
    if check_home_viability "/dev/$_DISK_DEV"; then
        show_confirm "Local Clone" "Preserve HOME?" "Do you want to preserve existing user data?" yes
        if [ $? -eq 0 ]; then
            _PRESERVE_HOME="true"
        fi
    fi

    local _CLONE_PROMPT="\n  $IMAGE\n     ||\n     ||\n     \\/\n  /dev/$DISK"
    if [ "$_PRESERVE_HOME" = "false" ]; then
        _CLONE_PROMPT="$_CLONE_PROMPT\n\nWARNING: All user data will be destroyed!"
    fi
    show_confirm "Local Clone" "Clone?" "$_CLONE_PROMPT"
    if [[ $? -eq 0 ]]; then
	IMAGE=$(echo "$IMAGE" | awk '{print $1}')
        DISK=$(echo "/dev/$DISK" | awk '{print $1}')
        START_TIME=$(date +%s)
        clone_HD "$IMAGES_DIR/$IMAGE" $DISK "$_PRESERVE_HOME"
        RET=$?
        END_TIME=$(date +%s)
        ELAPSED=$((END_TIME - START_TIME))
        DURATION=$(printf '%dm %ds' $((ELAPSED/60)) $((ELAPSED%60)))
        
        if [ $RET -eq 0 ]; then
            show_msg "Local Clone" "Completed!" "$IMAGE -> $DISK\n\nTime elapsed: $DURATION"
        else
            show_confirm "Local Clone" "Error" "The cloning process failed.\n\nWould you like to view the log now?" "yes"
            if [ $? -eq 0 ]; then
                clear
                less "$MCS_LOG_FILE"
            fi
        fi
    fi
}

network_clone_menu() {
    if [[ -z $SERVER_URL ]]; then
        show_msg "Network Clone" "Error" "Server URL is not configured!"
        return
    fi

    URL_PATH="http://$SERVER_URL/pool/mcs/"
    
    fetch_remote_projects "${URL_PATH}" > "$TEMPORAL_FILE"

    if [ ! -s "$TEMPORAL_FILE" ]; then
        show_msg "Network Clone" "Error" "No images found on the server:\n$URL_PATH"
        return
    fi

    FILE=$(show_selection "Network Clone" "Select remote image")
    if [[ -z $FILE ]]; then
        return
    fi
    FILE=$(echo "$FILE" | awk '{print $1}')

    DISK=$(get_disk)
    if [[ -z "$DISK" ]]; then
       return
    fi

    # Check if FILE is already a full URL
    if [[ $FILE == http* ]]; then
        DOWNLOAD_URL="$FILE"
    else
        DOWNLOAD_URL="$URL_PATH$FILE/"
    fi

    local _DISK_DEV=$(echo "$DISK" | awk '{print $1}')
    local _PRESERVE_HOME="false"

    load_partition_scheme "$DOWNLOAD_URL"
    if check_home_viability "/dev/$_DISK_DEV"; then
        show_confirm "Network Clone" "Preserve HOME?" "Do you want to preserve existing user data?" yes
        if [ $? -eq 0 ]; then
            _PRESERVE_HOME="true"
        fi
    fi

    local _CLONE_PROMPT="\n  $FILE\n     ||\n     ||\n     \\/\n  /dev/$DISK"
    if [ "$_PRESERVE_HOME" = "false" ]; then
        _CLONE_PROMPT="$_CLONE_PROMPT\n\nWARNING: All user data will be destroyed!"
    fi
    show_confirm "Network Clone" "Clone?" "$_CLONE_PROMPT"
    if [[ $? -eq 0 ]]; then
        # Clean disk name (remove size)
        DISK=$(echo "$DISK" | awk '{print $1}')
        clear
        mcs_log "[+] Starting Network Clone..."
        mcs_log "[+] Source: $DOWNLOAD_URL"
        mcs_log "[+] Target: /dev/$DISK"
        echo ""
        START_TIME=$(date +%s)
        clone_HD "$DOWNLOAD_URL" "/dev/$DISK" "$_PRESERVE_HOME"
        RET=$?
        END_TIME=$(date +%s)
        ELAPSED=$((END_TIME - START_TIME))
        DURATION=$(printf '%dm %ds' $((ELAPSED/60)) $((ELAPSED%60)))
        
        if [ $RET -eq 0 ]; then
            show_msg "Network Clone" "Completed!" "Successfully cloned $FILE to /dev/$DISK\n\nTime elapsed: $DURATION"
        else
            show_confirm "Network Clone" "Error" "The cloning process failed.\n\nWould you like to view the log now?" "yes"
            if [ $? -eq 0 ]; then
                clear
                less "$MCS_LOG_FILE"
            fi
        fi
    fi
}

# IMAGES
# ======

list_image() {
    local list=""
    local _DESC_FILE="$IMAGES_DIR/projects.json"
    for file in "$IMAGES_DIR"/*; do
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

download_image() {
    if [[ -z $SERVER_URL ]]; then
        dialog --msgbox "Server URL is not configured!" 10 50
        return
    fi

    URL_PATH="http://$SERVER_URL/pool/mcs/"

    fetch_remote_projects "${URL_PATH}" > "$TEMPORAL_FILE"

    if [ ! -s "$TEMPORAL_FILE" ]; then
        show_msg "Local Images" "Download" "No projects found on the server:\n$URL_PATH\n\nPlease check your Server URL or repository."
        return
    fi

    FILE=$(show_selection "Local Images" "Download")
    if [[ -z $FILE ]]; then
        return
    fi
    FILE=$(echo "$FILE" | awk '{print $1}')

    # Check if FILE is already a full URL
    if [[ $FILE == http* ]]; then
        DOWNLOAD_URL="$FILE"
    else
        DOWNLOAD_URL="$URL_PATH$FILE"
    fi

    if [ -e "$IMAGES_DIR/$FILE" ]; then
        show_msg "Local Images" "Error" "$FILE exists."
    else
        clear
        # It's a project directory
        FILE_DIR="$FILE/"
        DOWNLOAD_URL="$URL_PATH$FILE_DIR"
        mkdir -p "$IMAGES_DIR/$FILE_DIR"
        mcs_log "[+] Downloading project $FILE..."
        
        # 1. Download partition.yml first
        mcs_log "[+] Downloading partition.yml..."
        /usr/bin/wget -q --timeout=15 "${DOWNLOAD_URL}partition.yml" -O "$IMAGES_DIR/${FILE_DIR}partition.yml" 2>/dev/null

        # 1b. Download checksums.sha256 (optional integrity verification)
        mcs_log "[+] Downloading checksums.sha256..."
        /usr/bin/wget -q --timeout=15 "${DOWNLOAD_URL}checksums.sha256" -O "$IMAGES_DIR/${FILE_DIR}checksums.sha256" 2>/dev/null

        # 2. Verify integrity and determine parts from YAML (MANDATORY)
        local _PARTS
        if [ -s "$IMAGES_DIR/${FILE_DIR}partition.yml" ]; then
            # Load checksums for verification
            _CHECKSUMS_FILE="$IMAGES_DIR/${FILE_DIR}checksums.sha256"
            if ! verify_file_checksum "$IMAGES_DIR/${FILE_DIR}partition.yml" "partition.yml"; then
                rm -rf "$IMAGES_DIR/$FILE_DIR"
                show_msg "Network Clone" "Error" "Integrity check failed for partition.yml!"
                return 1
            fi
            _PARTS=$(yq -r '.partitions[].name' "$IMAGES_DIR/${FILE_DIR}partition.yml")
        else
            mcs_log "  [ERROR] partition.yml is mandatory for project download!"
            rm -rf "$IMAGES_DIR/$FILE_DIR"
            return 1
        fi

        # 3. Download .raw files
        local _RET=0
        for part_name in $_PARTS; do
            # Download all partitions except structural ones (BIOS, EFI, SWAP)
            if [[ "$part_name" != "BIOS" && "$part_name" != "EFI" && "$part_name" != "SWAP" ]]; then
                local _RAW="${part_name}.raw"
                mcs_log "[+] Downloading $_RAW..."
                /usr/bin/wget --timeout=30 "${DOWNLOAD_URL}${_RAW}" -O "$IMAGES_DIR/${FILE_DIR}${_RAW}"
                if [ $? -eq 0 ]; then
                    if ! verify_file_checksum "$IMAGES_DIR/${FILE_DIR}${_RAW}" "$_RAW"; then
                        _RET=1
                        break
                    fi
                else
                    _RET=1
                fi
            fi
        done

        if [ $_RET -eq 0 ]; then
            # Save project index locally for description lookups
            wget -q --timeout=15 -O "$IMAGES_DIR/projects.json" "${URL_PATH}projects.json" 2>/dev/null || :
            dialog --msgbox "Download project $FILE completed!" 10 50
        else
            dialog --msgbox "Download project $FILE failed!" 10 50
        fi
    fi
}

delete_image() {
    local IMAGE=$(get_image "Local Images" "Delete")
    if [[ -z "$IMAGE" ]]; then
        return
    fi

    # Check if the image exists locally
    if [ -e "$IMAGES_DIR/$IMAGE" ]; then
        show_confirm "Local Images" "Delete?" "Are you sure you want to delete project $IMAGE?"
        if [ $? = 0 ]; then
            # Clean disk name (remove size if present)
            local IMAGE_NAME=$(echo "$IMAGE" | awk '{print $1}')
            rm -rf "$IMAGES_DIR/$IMAGE_NAME"
            show_msg "Local Images" "Delete" "$IMAGE_NAME deleted."
        fi
    fi
}

images_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "${TITLE} > Local Images" \
                      --title "Local Images Menu" \
                      --menu "" 15 50 3 \
                      1 "List" \
                      2 "Download" \
                      3 "Delete" \
                      3>&1 1>&2 2>&3)

        case $CHOICE in
            1) list_image ;;
            2) download_image ;;
            3) delete_image ;;
            *) return ;;
        esac
    done
}


# SETTINGS
# ========

settings_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "${TITLE} > Settings" \
                      --title "Settings Menu" \
                      --menu "" 15 50 4 \
                      1 "Server: ${SERVER_URL}" \
                      2 "Server IP: ${SERVER_IP:-Dynamic (DNS)}" \
                      3 "Keymap: ${KEYMAP}" \
                      4 "Verify integrity: ${VERIFY_CHECKSUMS}" \
                      3>&1 1>&2 2>&3)

        case $CHOICE in
            1) setting_server ;;
            2) setting_ip ;;
            3) setting_keymap ;;
            4) setting_verify_checksums ;;
            *) return ;;
        esac
    done
}


setting_server() {
    SERVER_URL=$(dialog --stdout --inputbox "Enter the server URL:" 10 50 "$SERVER_URL")
    if [[ -n $SERVER_URL ]]; then
        yq -i ".settings.server = \"${SERVER_URL}\"" ${CONFIG_FILE}
        update_hosts
    fi
    TITLE="Migasfree Clone System ${TAG}"
}

setting_ip() {
    SERVER_IP=$(dialog --stdout --inputbox "Enter Server IP (leave empty for DNS):" 10 50 "$SERVER_IP")
    yq -i ".settings.server_ip = \"${SERVER_IP}\"" ${CONFIG_FILE}
    update_hosts
}

setting_keymap() {
    KEYMAP=$(get_keymap)
    if [[ -n $KEYMAP ]]; then
        yq -i ".settings.keymap = \"${KEYMAP}\"" ${CONFIG_FILE}
        loadkeys $KEYMAP
    fi
}

setting_verify_checksums() {
    if [ "$VERIFY_CHECKSUMS" = "true" ]; then
        VERIFY_CHECKSUMS="false"
    else
        VERIFY_CHECKSUMS="true"
    fi
    yq -i ".settings.verify_checksums = ${VERIFY_CHECKSUMS}" ${CONFIG_FILE}
    _VERIFY_CHECKSUMS=$VERIFY_CHECKSUMS
    show_msg "Settings" "Integrity verification" "Checksum verification is now: ${VERIFY_CHECKSUMS}"
}

quit() {
  clear
  exit 0
}

off() {
    clear
    info_msg "" "Poweroff" "Bye! Enjoy your day!" &
    poweroff -d 3 &
    (
       sleep 2
       clear
    ) &
    exit 0

}


download_ca() {
    local _CA_CERT="${SERVER_URL}.crt "
    echo "-----BEGIN CERTIFICATE-----" > /tmp/${_CA_CERT}
    openssl s_client -connect ${SERVER_URL}:443 -showcerts </dev/null 2>/dev/null | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | awk 'NR>=2&&NR<=42' >> /tmp/${_CA_CERT}
    cp /tmp/${_CA_CERT} /usr/local/share/ca-certificates/${_CA_CERT}
    update-ca-certificates
    rm /tmp/${_CA_CERT}
}

download_ca

main_menu
