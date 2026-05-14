#!/bin/bash
# Packages dist/VOCA.app into a distributable .dmg with a drag-to-Applications
# layout. Uses `create-dmg` if it's installed (prettier window setup); falls
# back to plain `hdiutil` otherwise.
#
# Usage:  ./scripts/make-dmg.sh [version]
# Output: dist/VOCA-<version>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="VOCA"
APP_DIR="dist/${APP_NAME}.app"
VERSION="${1:-${VERSION:-0.1.0}}"
DMG_PATH="dist/${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"

if [[ ! -d "${APP_DIR}" ]]; then
    echo "▸ ${APP_DIR} missing — building first"
    VERSION="${VERSION}" ./scripts/build-app.sh
fi

rm -f "${DMG_PATH}"

if command -v create-dmg >/dev/null 2>&1; then
    echo "▸ Using create-dmg"
    create-dmg \
        --volname "${VOLUME_NAME}" \
        --window-pos 200 120 \
        --window-size 600 380 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 175 170 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 425 170 \
        --no-internet-enable \
        "${DMG_PATH}" \
        "${APP_DIR}" >/dev/null
else
    echo "▸ create-dmg not found — falling back to hdiutil"
    echo "  (install with: brew install create-dmg)"
    STAGE=$(mktemp -d)
    trap 'rm -rf "$STAGE"' EXIT
    cp -R "${APP_DIR}" "${STAGE}/"
    ln -s /Applications "${STAGE}/Applications"
    hdiutil create \
        -volname "${VOLUME_NAME}" \
        -srcfolder "${STAGE}" \
        -ov \
        -format UDZO \
        "${DMG_PATH}" >/dev/null
fi

echo
echo "✅ ${DMG_PATH}"
du -h "${DMG_PATH}" | sed 's/^/    /'
shasum -a 256 "${DMG_PATH}" | sed 's/^/    /'
