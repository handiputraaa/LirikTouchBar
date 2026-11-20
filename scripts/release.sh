#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
./scripts/build-app.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
ZIP="LirikTouchBar-v${VERSION}.zip"

rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent LirikTouchBar.app "$ZIP"

echo "Created $ZIP"
echo "Upload it to a GitHub Release."
