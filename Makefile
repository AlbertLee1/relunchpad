# SWIFTPM_CUSTOM_LIBS_DIR works around a broken CommandLineTools install where
# stale 2024-era .private.swiftinterface files shadow the current manifest API.
# See Scripts/fix-toolchain.sh for how ~/.relaunchpad-toolchain is produced.
export SWIFTPM_CUSTOM_LIBS_DIR := $(wildcard $(HOME)/.relaunchpad-toolchain)

.PHONY: build app run test clean

build:
	swift build

app:
	./Scripts/make-app.sh

run: app
	open ReLaunchpad.app

test:
	swift test

clean:
	rm -rf .build ReLaunchpad.app
