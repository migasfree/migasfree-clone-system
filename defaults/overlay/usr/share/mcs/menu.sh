#!/bin/bash

source /usr/share/mcs/functions

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
    dialog --backtitle "$TITLE > $backtitle" --title "$title" --defaultno --yesno "$prompt" 12 50
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
    _KNAME=$( \
        lsblk -o KNAME,TYPE,LABEL | \
        awk '$2 == "disk" {print $0}' | \
        grep "$_LABEL" | \
        awk '{print $1}'
        )
    if [ -z $_KNAME ]
    then
        return 1
    else
        echo "/dev/${_KNAME}"
    fi
}

find_partition_by_label() {
    local _LABEL="$1"
    _KNAME=$( \
        lsblk -o KNAME,TYPE,LABEL | \
        awk '$2 == "part" {print $0}' | \
        grep "$_LABEL" | \
        awk '{print $1}'
        )
    if [ -z $_KNAME ]
    then
        return 1
    else
        echo "/dev/${_KNAME}"
    fi
}

# LOAD SETTINGS
# =============
SERVER_URL=$(yq '.settings.server' < ${CONFIG_FILE})
KEYMAP=$(yq '.settings.keymap' < ${CONFIG_FILE})
TITLE="Migasfree Clone System ${TAG}"


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
                      1 "Clone from Network" \
                      2 "Clone from USB" \
                      3 "Images (Manage USB)" \
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

get_image() {
    local submenu="$1"
    local title="$2"
    rm -f "$TEMPORAL_FILE"
    local INDEX=1
    for file in "$IMAGES_DIR"/*; do
        if [ -f "$file" ]; then
            NAME=$(basename "$file")
            SIZE=$(stat -c %s "$file")
            echo "${INDEX} \"${NAME} $(numfmt --to=iec $SIZE)\"" >> "$TEMPORAL_FILE"
            INDEX=$((INDEX + 1))
        fi
    done
    
    if [ "$INDEX" -gt 1 ]; then
        echo $(show_selection "$submenu" "$title")
    else
        echo ""
    fi
}

get_disk() {
    rm -f "$TEMPORAL_FILE"
    local INDEX=1
    local MCS_DISK=$(disk_by_label "MCS_ROOT")
    lsblk_output=$(lsblk -nd --output NAME,SIZE,TYPE)
    while IFS=' ' read -r NAME SIZE TYPE; do
        if [ "$TYPE" = "disk" ]; then
            # Excluding floppy, mcs usb, or disk size=0B

            if ! [[ "${NAME}" = "fd0" || "/dev/${NAME}" = "${MCS_DISK}" || "${SIZE}" = "0B" ]]; then
                echo "${INDEX} \"${NAME} ${SIZE}\"" >> "$TEMPORAL_FILE"
                INDEX=$((INDEX + 1))
            fi
        fi
    done <<< "$lsblk_output"
    echo "$(show_selection "Clone" "Destination disk")"
}


get_keymap() {
    rm -f "$TEMPORAL_FILE"
    local INDEX=1
    local _output=$(ls /usr/share/keymaps/xkb/*.map.gz)
    while IFS=' ' read -r NAME; do
            echo "${INDEX} \"$(basename ${NAME%.map.gz})\"" >> "$TEMPORAL_FILE"
            INDEX=$((INDEX + 1))
    done <<< "$_output"
    echo "$(show_selection "Settings" "Keymap")"
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
    show_confirm "Local Clone" "Are you sure you want to clone?" "\n\n$IMAGE\n  |\n \|/\n  '\n$DISK?"
    if [[ $? -eq 0 ]]; then
	IMAGE=$(echo "$IMAGE" | awk '{print $1}')
        DISK=$(echo "/dev/$DISK" | awk '{print $1}')
        #dd if="$IMAGES_DIR/$IMAGE" of="$DISK" bs=4M status=progress
        clone_HD "$IMAGES_DIR/$IMAGE" $DISK
        show_msg "Local Clone" "Completed!" "$IMAGE -> $DISK"
    fi
}

network_clone_menu() {
    if [[ -z $SERVER_URL ]]; then
        show_msg "Network Clone" "Error" "Server URL is not configured!"
        return
    fi

    URL_PATH="http://$SERVER_URL/pool/images/"
    
    # Fetch remote image list
    wget -q -O - "${URL_PATH}" | grep -o 'href="[^"]*"' |  grep ".qcow2" | cut -d '"' -f 2 | nl -w1 -s' ' | sed 's/\(.*\) \(.*\)/\1 "\2"/' > $TEMPORAL_FILE

    if [ ! -s "$TEMPORAL_FILE" ]; then
        show_msg "Network Clone" "Error" "No images found on the server:\n$URL_PATH"
        return
    fi

    FILE=$(show_selection "Network Clone" "Select remote image")
    if [[ -z $FILE ]]; then
        return
    fi

    DISK=$(get_disk)
    if [[ -z "$DISK" ]]; then
       return
    fi

    show_confirm "Network Clone" "Start direct streaming?" "\nFROM: $FILE\nTO: /dev/$DISK\n\nWARNING: All data on /dev/$DISK will be lost!"
    if [[ $? -eq 0 ]]; then
        clear
        echo "[+] Starting direct Network Clone..."
        echo "[+] Source: $URL_PATH$FILE"
        echo "[+] Target: /dev/$DISK"
        echo ""
        # Direct stream: wget -> qemu-img convert
        wget -qO- "$URL_PATH$FILE" | qemu-img convert -p -f qcow2 -O raw - "/dev/$DISK"
        
        if [ $? -eq 0 ]; then
            show_msg "Network Clone" "Completed!" "Successfully cloned $FILE to /dev/$DISK"
        else
            show_msg "Network Clone" "Error" "The cloning process failed. Check network connection."
        fi
    fi
}

# IMAGES
# ======

list_image() {
    local list=$(ls -lh "$IMAGES_DIR" | awk 'NR>1 {print $9, "("$5")"}')
    if [[ -z "$list" ]]; then
        show_msg "Images" "List" "No images found in $IMAGES_DIR"
    else
        show_msg "Images" "List" "$list"
    fi
}

download_image() {
    if [[ -z $SERVER_URL ]]; then
        dialog --msgbox "Server URL is not configured!" 10 50
        return
    fi

    URL_PATH="http://$SERVER_URL/pool/images/"

    echo "" > $TEMPORAL_FILE

    wget -q -O - "${URL_PATH}" | grep -o 'href="[^"]*"' |  grep ".qcow2" | cut -d '"' -f 2 |nl -w1 -s' ' | sed 's/\(.*\) \(.*\)/\1 "\2"/' > $TEMPORAL_FILE

    if [ ! -s "$TEMPORAL_FILE" ]; then
        show_msg "Images" "Download" "No .qcow2 images found on the server:\n$URL_PATH\n\nPlease check your Server URL or repository."
        return
    fi

    FILE=$(show_selection "Images" "Download")
    if [[ -z $FILE ]]; then
        return
    fi

    if [ -f "$IMAGES_DIR/$FILE" ]; then
        show_msg "Images" "Error" "$FILE exists."
    else
        clear
        wget "$URL_PATH/$FILE" -P "$IMAGES_DIR"
        if [ $? = 0 ]
        then
            dialog --msgbox "Download $FILE completed!" 10 50
        else
            read
            dialog --msgbox "Download $FILE failed!" 10 50
        fi
    fi
}

delete_image() {
    if [ -z "$(ls -A "$IMAGES_DIR")" ]; then
        show_msg "Images" "Delete" "No images found to delete."
        return
    fi
    IMAGE=$(get_image "Images" "Delete")
    if [[ -z $IMAGE ]]; then
        return
    fi
    show_confirm "Images" "Are you sure you want to delete?" "$IMAGE"
    if [[ $? -eq 0 ]]; then
	    IMAGE=$(echo $IMAGE|awk '{print $1}')
        rm -f "$IMAGES_DIR/$IMAGE"
    fi
}

images_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "${TITLE} > Images" \
                      --title "Images Menu" \
                      --menu "" 15 50 2 \
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
                      --menu "" 15 50 2 \
                      1 "server: ${SERVER_URL}" \
                      2 "keymap: ${KEYMAP}" \
                      3>&1 1>&2 2>&3)

        case $CHOICE in
            1) setting_server ;;
            2) setting_keymap ;;
            *) return ;;
        esac
    done
}


setting_server() {
    SERVER_URL=$(dialog --stdout --inputbox "Enter the server URL:" 10 50 "$SERVER_URL")
    if [[ -n $SERVER_URL ]]; then
        yq -i ".settings.server = \"${SERVER_URL}\"" ${CONFIG_FILE}
    fi
    TITLE="Migasfree Clone System ${TAG}"
}

setting_keymap() {
    KEYMAP=$(get_keymap)
    if [[ -n $KEYMAP ]]; then
        yq -i ".settings.keymap = \"${KEYMAP}\"" ${CONFIG_FILE}
        loadkeys $KEYMAP
    fi
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

#check_resolv

main_menu
