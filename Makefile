# Migasfree Clone System (MCS) Build System

.PHONY: build test test-boot test-usb usb clean help test-unit

help:
	@echo "MCS Command Center"
	@echo "------------------"
	@echo "Usage:"
	@echo "  make build        Build the MCS bootable ISO image"
	@echo "  make test         Launch QEMU with MCS ISO and a target disk"
	@echo "  make test-boot    Verify the cloned target disk by booting it"
	@echo "  make test-usb     Launch QEMU using a physical USB (e.g. make test-usb DRIVE=/dev/sdX)"
	@echo "  make test-unit    Run unit tests (bats-core) — 66 tests"
	@echo "  make usb          Create a physical bootable USB drive"
	@echo "  make clean        Remove generated artifacts and temporary files"

build:
	sudo ./scripts/build.sh

test:
	sudo ./scripts/test.sh $(ARGS)

test-boot:
	sudo ./scripts/test-boot.sh

test-usb:
	@[ "${DRIVE}" ] || ( echo "Error: DRIVE variable is not set. Usage: make test-usb DRIVE=/dev/sdX"; exit 1 )
	sudo ./scripts/test.sh -d $(DRIVE)

usb:
	sudo ./scripts/makeusb.sh

test-unit:
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats-core is not installed. See docs/tests.md for setup."; exit 1; }
	bats tests/bats/

clean:
	sudo rm -rf artifacts/*
	sudo rm -f /tmp/qemu-monitor.sock
