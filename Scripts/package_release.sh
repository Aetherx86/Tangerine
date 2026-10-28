#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "🍊 Building fresh Tangerine.app..."
./Scripts/build_app.sh

echo "📦 Creating Tangerine.dmg installer..."
DMG_STAGING="/tmp/tangerine_dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

cp -R /Applications/Tangerine.app "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

rm -f Tangerine.dmg
hdiutil create -volname "Tangerine" -srcfolder "$DMG_STAGING" -ov -format UDZO Tangerine.dmg
rm -rf "$DMG_STAGING"

echo "✅ Installer created successfully: Tangerine.dmg"
ls -lh Tangerine.dmg
