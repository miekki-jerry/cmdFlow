#!/bin/bash
# Buduje cmdFlow.app i pakuje do .dmg oraz .zip do dystrybucji.
# Użycie: Scripts/make_release.sh [wersja]
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
VERSION="${1:-0.1.0}"

"${ROOT}/Scripts/build_app.sh" "$VERSION"

APP="${ROOT}/dist/cmdFlow.app"
DMG="${ROOT}/dist/cmdFlow-${VERSION}.dmg"
ZIP="${ROOT}/dist/cmdFlow-${VERSION}.zip"

echo "▶ Tworzenie ZIP…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "▶ Tworzenie DMG…"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "cmdFlow" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "✓ Artefakty:"
echo "   $DMG"
echo "   $ZIP"
