#!/bin/bash
# Build VoiceType.app — a proper macOS bundle with Info.plist for
# microphone + accessibility permissions and an ad-hoc code signature.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG=${CONFIG:-release}
APP_NAME="VoiceType"
BUNDLE_ID="com.voicetype.app"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"

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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
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

# Ad-hoc sign so TCC, mic, and accessibility prompts can identify the bundle.
echo "▸ Signing (ad-hoc)"
codesign --force --deep --sign - --options runtime "${APP_DIR}" >/dev/null

echo "✅ ${APP_DIR}"
