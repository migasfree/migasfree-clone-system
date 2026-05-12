# Migasfree Clone System (MCS) Build System

.PHONY: build qemu-clone qemu-boot qemu-usb test flash clean help

help:
	@echo "MCS Command Center"
	@echo "------------------"
	@echo "Usage:"
	@echo "  make build        Build the MCS bootable ISO image"
	@echo "  make qemu-clone   Launch QEMU with MCS ISO and a target disk (interactive clone test)"
	@echo "  make qemu-boot    Verify the cloned target disk by booting it in QEMU"
	@echo "  make qemu-usb     Launch QEMU using a physical USB (e.g. make qemu-usb DRIVE=/dev/sdX)"
	@echo "  make test         Run unit tests (bats-core, 66 tests)"
	@echo "  make flash        Write the MCS ISO to a physical USB drive"
	@echo "  make clean        Remove generated artifacts and temporary files"

build:
	sudo ./scripts/build.sh

qemu-clone:
	sudo ./scripts/qemu-clone.sh $(ARGS)

qemu-boot:
	sudo ./scripts/qemu-boot.sh

qemu-usb:
	@[ "${DRIVE}" ] || ( echo "Error: DRIVE variable is not set. Usage: make qemu-usb DRIVE=/dev/sdX"; exit 1 )
	sudo ./scripts/qemu-clone.sh -d $(DRIVE)

flash:
	sudo ./scripts/flash.sh

test:
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats-core is not installed. See docs/tests.md for setup."; exit 1; }
	bats tests/bats/

clean:
	sudo rm -rf artifacts/*
	sudo rm -f /tmp/qemu-monitor.sock
