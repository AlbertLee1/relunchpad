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

# CLT keeps Testing.framework and its lib_TestingInterop.dylib in places the
# default test runner does not search; pass them explicitly.
CLT_FRAMEWORKS := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
CLT_TESTLIBS := /Library/Developer/CommandLineTools/Library/Developer/usr/lib

test:
	swift test \
		-Xswiftc -F$(CLT_FRAMEWORKS) \
		-Xlinker -F$(CLT_FRAMEWORKS) \
		-Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS) \
		-Xlinker -rpath -Xlinker $(CLT_TESTLIBS)

clean:
	rm -rf .build ReLaunchpad.app
