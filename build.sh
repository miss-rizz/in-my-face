#!/bin/bash
set -e

APP="InMyFace"
BUNDLE=".build/$APP.app"
CONTENTS="$BUNDLE/Contents"

echo "Cleaning..."
rm -rf ".build"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

echo "Compiling..."
swiftc Sources/*.swift \
    -framework Cocoa \
    -framework EventKit \
    -framework SwiftUI \
    -sdk "$(xcrun --show-sdk-path)" \
    -O \
    -o "$CONTENTS/MacOS/$APP"

echo "Bundling..."
cp Info.plist "$CONTENTS/"
cp Resources/* "$CONTENTS/Resources/"

echo "Signing..."
codesign --force --sign - "$BUNDLE"

echo ""
echo "Build complete."
echo "Run now:     open $BUNDLE"
echo ""
echo "To auto-start on login:"
echo "  cp -r $BUNDLE /Applications/"
echo "  Then: System Settings > General > Login Items > add InMyFace"
