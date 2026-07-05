#!/bin/bash
# Buduje cmdFlow.app z pakietu SPM (bez Xcode project).
# Użycie: Scripts/build_app.sh [wersja]
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

VERSION="${1:-0.1.0}"
BUILD="${GITHUB_RUN_NUMBER:-1}"
APP_NAME="cmdFlow"
CONFIG="release"

echo "▶ Kompilacja (${CONFIG})…"
swift build -c "$CONFIG" --arch arm64

BIN_PATH="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)/${APP_NAME}"

APP="${ROOT}/dist/${APP_NAME}.app"
echo "▶ Składanie ${APP}…"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS"
mkdir -p "${APP}/Contents/Resources"

cp "$BIN_PATH" "${APP}/Contents/MacOS/${APP_NAME}"

# Info.plist z podstawioną wersją
sed -e "s/__VERSION__/${VERSION}/g" -e "s/__BUILD__/${BUILD}/g" \
    "${ROOT}/Resources/Info.plist" > "${APP}/Contents/Info.plist"

# Ikona
echo "▶ Generowanie ikony…"
swift "${ROOT}/Scripts/make_icon.swift" "${APP}/Contents/Resources/AppIcon.icns" || \
    echo "  (pominięto ikonę — build przebiegnie bez niej)"

# Ad-hoc signature — pozwala uruchomić lokalnie zbudowaną apkę bez „uszkodzony".
echo "▶ Podpis ad-hoc…"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (codesign pominięty)"

echo "✓ Gotowe: ${APP}"
