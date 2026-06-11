#!/bin/bash
# This machine's CommandLineTools contains stale (Feb 2024) *.private.swiftinterface
# files inside PackageDescription.swiftmodule / PackagePlugin.swiftmodule that
# shadow the current Swift 6.3 interfaces, breaking every SPM manifest compile.
#
# Without sudo we cannot fix /Library/Developer/CommandLineTools, so we copy the
# manifest API to ~/.relaunchpad-toolchain with the stale files removed and point
# SWIFTPM_CUSTOM_LIBS_DIR at it (the Makefile does this automatically).
#
# Permanent fix (requires sudo):
#   sudo zsh -c 'for f in /Library/Developer/CommandLineTools/usr/lib/swift/pm/{ManifestAPI/PackageDescription,PluginAPI/PackagePlugin}.swiftmodule/*.private.swiftinterface; do mv "$f" "$f.stale"; done'
set -euo pipefail

PM=/Library/Developer/CommandLineTools/usr/lib/swift/pm
DEST="$HOME/.relaunchpad-toolchain"

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$PM/ManifestAPI" "$PM/PluginAPI" "$DEST/"
rm -f "$DEST"/ManifestAPI/PackageDescription.swiftmodule/*.private.swiftinterface \
      "$DEST"/PluginAPI/PackagePlugin.swiftmodule/*.private.swiftinterface
echo "Patched manifest API copied to $DEST"
