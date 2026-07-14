#!/bin/bash
# Build VOCA.app — a proper macOS bundle with Info.plist for microphone +
# accessibility permissions, signed with a stable self-signed identity so
# macOS TCC remembers permissions across rebuilds.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

CONFIG=${CONFIG:-release}
APP_NAME="VOCA"
BUNDLE_ID="com.voca.app"
DISPLAY_NAME="VOCA"
VERSION=${VERSION:-0.1.0}
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CERT_CN="VOCA Dev"
KEYCHAIN_PATH="${PROJECT_ROOT}/build/voca-signing.keychain-db"
KEYCHAIN_PASS="voca"

# Signing identity. Default: the stable local self-signed "VOCA Dev" cert,
# which keeps macOS TCC (Microphone / Accessibility) grants across local
# rebuilds. Set SIGN_IDENTITY to override — CI passes "-" for ad-hoc signing,
# which needs no keychain or certificate and runs headlessly. (The interactive
# keychain setup below would hang forever on a headless CI runner.)
SIGN_IDENTITY="${SIGN_IDENTITY:-${CERT_CN}}"
USE_PROJECT_KEYCHAIN=0
[[ "${SIGN_IDENTITY}" == "${CERT_CN}" ]] && USE_PROJECT_KEYCHAIN=1

# Ensure the project-local signing keychain + identity exist (local dev only).
if [[ "${USE_PROJECT_KEYCHAIN}" == "1" ]]; then
    if [[ ! -f "${KEYCHAIN_PATH}" ]] || \
       ! security find-identity -p codesigning -v "${KEYCHAIN_PATH}" 2>/dev/null \
           | grep -qF "\"${CERT_CN}\""; then
        echo "▸ Local signing keychain or '${CERT_CN}' identity missing — running setup-signing.sh"
        "$(dirname "$0")/setup-signing.sh"
    fi
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

# Copy SwiftPM resource bundles (e.g. VOCA_VOCA.bundle, which holds the in-app
# logo) into Resources/ so `Bundle.module` can find them at runtime.
for res_bundle in "${BIN_PATH}"/*.bundle; do
    [ -e "${res_bundle}" ] && cp -R "${res_bundle}" "${APP_DIR}/Contents/Resources/"
done

# Bundle icon. Rebuilds the .icns from Resources/logo.png if it's missing.
if [[ ! -f Resources/VOCA.icns ]]; then
    "$(dirname "$0")/make-icon.sh"
fi
cp Resources/VOCA.icns "${APP_DIR}/Contents/Resources/VOCA.icns"

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
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>VOCA.icns</string>
    <key>CFBundleIconName</key>
    <string>VOCA</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>VOCA needs access to your microphone to transcribe your speech.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>VOCA uses on-device Apple Speech as an offline transcription option.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>VOCA inserts transcribed text by simulating a paste shortcut.</string>
</dict>
</plist>
PLIST

ENTITLEMENTS="$(dirname "$0")/VOCA.entitlements"

if [[ "${USE_PROJECT_KEYCHAIN}" == "1" ]]; then
    echo "▸ Signing with '${SIGN_IDENTITY}' + entitlements (project-local keychain)"

    # Save the user's current keychain search list so we can restore it on exit.
    # codesign requires the signing keychain to be in the search list at the
    # moment it runs; macOS does not honour --keychain alone for that lookup.
    # We temporarily prepend our project keychain and guarantee a restore via
    # `trap`, so the user's search list is unchanged once this script finishes
    # — even if codesign fails or the user hits Ctrl-C.
    ORIG_SEARCH_LIST=$(security list-keychains -d user | sed -E 's/^[[:space:]]*//' | tr -d '"')
    restore_search_list() {
        if [[ -n "${ORIG_SEARCH_LIST:-}" ]]; then
            # shellcheck disable=SC2086
            security list-keychains -d user -s ${ORIG_SEARCH_LIST} >/dev/null
        fi
    }
    trap restore_search_list EXIT INT TERM

    # Temporarily add the project keychain to the front of the search list.
    # shellcheck disable=SC2086
    security list-keychains -d user -s "${KEYCHAIN_PATH}" ${ORIG_SEARCH_LIST} >/dev/null

    # Unlock in case it auto-locked since the last build.
    security unlock-keychain -p "${KEYCHAIN_PASS}" "${KEYCHAIN_PATH}" >/dev/null

    # --keychain narrows codesign's identity search to just our project keychain.
    codesign --force --deep --sign "${SIGN_IDENTITY}" \
        --keychain "${KEYCHAIN_PATH}" \
        --options runtime \
        --entitlements "${ENTITLEMENTS}" \
        "${APP_DIR}" >/dev/null
    # restore_search_list runs via trap on EXIT
else
    # Explicit identity (e.g. "-" for ad-hoc in CI). No keychain, no search-list
    # manipulation — runs headlessly. The artifact is still opened via the
    # documented right-click → Open Gatekeeper bypass.
    echo "▸ Signing with identity '${SIGN_IDENTITY}' + entitlements (no keychain)"
    codesign --force --deep --sign "${SIGN_IDENTITY}" \
        --options runtime \
        --entitlements "${ENTITLEMENTS}" \
        "${APP_DIR}" >/dev/null
fi

echo
echo "✅ ${APP_DIR}"
echo
codesign -dvv "${APP_DIR}" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier|Signature" | sed 's/^/    /' || true
