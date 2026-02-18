#!/bin/bash
# Packages QuickTask.app into a distributable DMG file
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="QuickTask"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
STAGING_DIR=$(mktemp -d -t quicktask-dmg)

echo "=== Building $APP_NAME ==="
bash build-app.sh

echo ""
echo "=== Copying resource bundle into app ==="
RESOURCE_BUNDLE=".build/release/QuickTask_QuickTask.bundle"
mkdir -p "$APP_BUNDLE/Contents/Resources"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
    echo "Copied $RESOURCE_BUNDLE into $APP_BUNDLE/Contents/Resources/"
else
    echo "Warning: Resource bundle not found at $RESOURCE_BUNDLE (app may still work without bundled resources)"
fi

echo ""
echo "=== Creating DMG ==="

# Stage the DMG contents
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create compressed, read-only DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

# Clean up staging directory
rm -rf "$STAGING_DIR"

echo ""
echo "=== Done ==="
echo "Output: $(pwd)/$DMG_NAME"
echo "Size:   $(du -h "$DMG_NAME" | cut -f1)"
