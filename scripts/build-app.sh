#!/bin/bash
# Build VoiceType.app — a proper macOS bundle with Info.plist for
# microphone + accessibility permissions, signed with a stable self-signed
# identity so macOS TCC remembers permissions across rebuilds.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG=${CONFIG:-release}
APP_NAME="VoiceType"
BUNDLE_ID="com.voicetype.app"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CERT_CN="VoiceType Dev"

# Ensure a stable signing identity exists.
if ! security find-identity -p codesigning -v 2>/dev/null | grep -qF "\"${CERT_CN}\""; then
    echo "▸ Stable signing identity '${CERT_CN}' missing — running setup-signing.sh"
    "$(dirname "$0")/setup-signing.sh"
fi

echo "▸ swift build --configuration ${CONFIG}"
swift build --configuration "${CONFIG}"

BIN_PATH=$(swift build --configuration "${CONFIG}" --show-bin-path)
EXE_PATH="${BIN_PATH}/${APP_NAME}"

if [[ ! -x "${EXE_PATH}" ]]; then
    echo "❌ Built binary missing at ${EXE_PATH}" >&2
    exit 1
fi

echo "▸ Building bundle at ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${EXE_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Bundle icon. Rebuilds the .icns from Resources/logo.png if it's missing.
if [[ ! -f Resources/VoiceType.icns ]]; then
    "$(dirname "$0")/make-icon.sh"
fi
cp Resources/VoiceType.icns "${APP_DIR}/Contents/Resources/VoiceType.icns"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>VoiceType</string>
    <key>CFBundleIconFile</key>
    <string>VoiceType.icns</string>
    <key>CFBundleIconName</key>
    <string>VoiceType</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>VoiceType needs access to your microphone to transcribe your speech.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>VoiceType uses on-device Apple Speech as an offline transcription option.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>VoiceType inserts transcribed text by simulating a paste shortcut.</string>
</dict>
</plist>
PLIST

ENTITLEMENTS="$(dirname "$0")/VoiceType.entitlements"
echo "▸ Signing with '${CERT_CN}' + entitlements"
codesign --force --deep --sign "${CERT_CN}" \
    --options runtime \
    --entitlements "${ENTITLEMENTS}" \
    "${APP_DIR}" >/dev/null

echo
echo "✅ ${APP_DIR}"
echo
codesign -dvv "${APP_DIR}" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier|Signature" | sed 's/^/    /'
