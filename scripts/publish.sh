#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -lt 2 ]]; then
    echo "Usage: ./scripts/publish.sh 1.0.1 \"what changed\""
    exit 1
fi

VERSION="$1"
MESSAGE="$2"

# Bump both version fields in Info.plist.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist >/dev/null
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $((BUILD + 1))" Resources/Info.plist >/dev/null

git add -A
git commit -m "$MESSAGE"
git push

./scripts/release.sh

echo ""
echo "Published $VERSION. Upload LirikTouchBar-v${VERSION}.zip to a GitHub Release."
