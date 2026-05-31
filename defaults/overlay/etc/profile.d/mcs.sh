#!/bin/sh

CONFIG_FILE="config.yml"

clear

setfont /usr/share/consolefonts/ter-132n.psf.gz

# Ensure config.yml is initialized before reading the keymap
if ! [ -d "/mcsdata" ]; then
  mkdir -p /mcsdata
fi
if ! [ -f "/mcsdata/${CONFIG_FILE}" ]; then
  cp /usr/share/mcs/config.yml /mcsdata/${CONFIG_FILE}
fi

KEYMAP=$(yq '.settings.keymap' < /mcsdata/${CONFIG_FILE})
loadkeys ${KEYMAP}

if [ "$(tty)" = "/dev/tty1" ]
then
  /usr/share/mcs/menu.sh
fi

if [ "$(tty)" = "/dev/tty2" ]
then
  clear
  echo "MCS Real-time Log Viewer (tty2)"
  echo "Press Ctrl+C to drop to shell"
  echo "-------------------------------"
  # Use hardcoded path to avoid sourcing functions here
  touch /var/log/mcs-clone.log
  tail -f /var/log/mcs-clone.log
fi

