#!/bin/sh

CONFIG_FILE="config.yml"

clear

setfont /usr/share/consolefonts/ter-132n.psf.gz

KEYMAP=$(yq '.settings.keymap' < /mcsdata/${CONFIG_FILE})
loadkeys ${KEYMAP}

if [ "$(tty)" = "/dev/tty1" ]
then
  /usr/share/mcs/menu.sh
fi

