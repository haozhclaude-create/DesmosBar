#!/bin/sh
# Build DesmosBar from main.swift and install it to ~/Applications/DesmosBar.app
set -e
cd "$(dirname "$0")"
APP="$HOME/Applications/DesmosBar.app"
swiftc -O main.swift -o DesmosBar
pkill -x DesmosBar || true
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp DesmosBar "$APP/Contents/MacOS/DesmosBar"
# Stable identity so the Accessibility permission survives rebuilds
# (plain ad-hoc signing changes identity on every build and macOS forgets the grant).
codesign --force --sign - -r '=designated => identifier "local.desmosbar"' "$APP"
open "$APP"
