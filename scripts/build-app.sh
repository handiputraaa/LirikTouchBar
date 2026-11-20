#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP="LirikTouchBar.app"
HOST="$(uname -m)"

if [[ "$HOST" == "x86_64" ]]; then
    OTHER="arm64"
else
    OTHER="x86_64"
fi

HOST_BIN=".build/${HOST}-apple-macosx/${CONFIG}/LirikTouchBar"
OTHER_BIN=".build/${OTHER}-apple-macosx/${CONFIG}/LirikTouchBar"
UNIVERSAL=".build/${CONFIG}-universal-LirikTouchBar"

echo "Building for $HOST..."
swift build -c "$CONFIG" --arch "$HOST"

echo "Building for $OTHER..."
if swift build -c "$CONFIG" --arch "$OTHER" >/dev/null 2>&1 && [[ -f "$OTHER_BIN" ]]; then
    lipo -create -output "$UNIVERSAL" "$HOST_BIN" "$OTHER_BIN"
    echo "Universal binary ($HOST + $OTHER)"
else
    echo "Warning: could not build the $OTHER slice; building $HOST only."
    cp "$HOST_BIN" "$UNIVERSAL"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$UNIVERSAL" "$APP/Contents/MacOS/LirikTouchBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc sign so macOS Gatekeeper accepts a locally built app.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP"
echo "Run it with: open $APP"
