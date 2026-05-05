# Migasfree Clone System (MCS) Build System

.PHONY: build test test-boot usb clean help

help:
	@echo "MCS Command Center"
	@echo "------------------"
	@echo "Usage:"
	@echo "  make build        Build the MCS bootable ISO image"
	@echo "  make test         Launch QEMU with MCS ISO and a target disk"
	@echo "  make test-boot    Verify the cloned target disk by booting it"
	@echo "  make usb          Create a physical bootable USB drive"
	@echo "  make clean        Remove generated artifacts and temporary files"

build:
	sudo ./scripts/build.sh

test:
	sudo ./scripts/test.sh

test-boot:
	sudo ./scripts/test-boot.sh

usb:
	sudo ./scripts/makeusb.sh

clean:
	sudo rm -rf artifacts/*
	sudo rm -f /tmp/qemu-monitor.sock
