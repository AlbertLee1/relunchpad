#!/bin/bash
# Assemble ReLaunchpad.app from the SPM release build and sign it.
#
# TCC permissions (Input Monitoring / Accessibility) are anchored to the code
# signature. Ad-hoc signing changes the cdhash on every build, forcing
# re-authorization each time. Create a self-signed code-signing certificate
# named "ReLaunchpad Dev" in Keychain Access once, and this script will use it.
set -euo pipefail

cd "$(dirname "$0")/.."

# Work around the broken CommandLineTools manifest API (see fix-toolchain.sh).
if [ -d "$HOME/.relaunchpad-toolchain" ]; then
    export SWIFTPM_CUSTOM_LIBS_DIR="$HOME/.relaunchpad-toolchain"
fi

SIGN_IDENTITY="${SIGN_IDENTITY:-ReLaunchpad Dev}"
APP="ReLaunchpad.app"
BIN=".build/release/ReLaunchpad"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/ReLaunchpad"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Embed the OpenMultitouchSupport binary framework and let the executable find it.
OMS_FRAMEWORK=".build/artifacts/openmultitouchsupport/OpenMultitouchSupportXCF/OpenMultitouchSupportXCF.xcframework/macos-arm64_x86_64/OpenMultitouchSupportXCF.framework"
cp -R "$OMS_FRAMEWORK" "$APP/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/ReLaunchpad"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

# No hardened runtime: its library validation rejects frameworks signed by a
# self-signed identity (no Team ID), and we don't notarize local builds.
if security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
    codesign --force --sign "$SIGN_IDENTITY" "$APP/Contents/Frameworks/OpenMultitouchSupportXCF.framework"
    codesign --force --sign "$SIGN_IDENTITY" "$APP"
    echo "Signed with: $SIGN_IDENTITY"
else
    codesign --force --sign - "$APP/Contents/Frameworks/OpenMultitouchSupportXCF.framework"
    codesign --force --sign - "$APP"
    echo "WARNING: certificate '$SIGN_IDENTITY' not found; used ad-hoc signing." >&2
    echo "         TCC permissions will reset on every rebuild. Create a" >&2
    echo "         self-signed code-signing certificate in Keychain Access." >&2
fi

echo "Built $APP"
