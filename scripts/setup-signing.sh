#!/bin/bash
# Creates a stable self-signed code-signing certificate inside a dedicated
# password-less keychain. Run this ONCE. Subsequent `build-app.sh` runs
# will use the cert silently — no system prompts, no "allow codesign"
# dialog, no permission resets between rebuilds.
#
# Why this matters: macOS TCC remembers Microphone / Accessibility grants
# by the app's signing identity. Ad-hoc signs produce a new identity for
# every build, so permissions reset on every relaunch. A stable cert
# keeps the identity constant.
set -euo pipefail

CERT_CN="VOCA Dev"
KEYCHAIN_NAME="voca-signing.keychain-db"
KEYCHAIN_PATH="${HOME}/Library/Keychains/${KEYCHAIN_NAME}"

if security find-identity -p codesigning -v "${KEYCHAIN_PATH}" 2>/dev/null | grep -qF "\"${CERT_CN}\""; then
    echo "✓ Code-signing identity '${CERT_CN}' already present in ${KEYCHAIN_NAME}."
    exit 0
fi

echo "▸ Creating dedicated signing keychain at ${KEYCHAIN_PATH}…"
# Empty password keychain. We never store anything sensitive in it — only
# the locally-generated dev cert.
security create-keychain -p "" "${KEYCHAIN_PATH}" 2>/dev/null || true
security unlock-keychain -p "" "${KEYCHAIN_PATH}"
# Don't lock automatically.
security set-keychain-settings "${KEYCHAIN_PATH}"

# Add to the search list so codesign finds the identity here too.
SEARCH=$(security list-keychains -d user | sed 's/\"//g' | tr -d ' ')
if ! echo "$SEARCH" | grep -qF "${KEYCHAIN_PATH}"; then
    EXISTING=$(security list-keychains -d user | sed 's/\"//g')
    security list-keychains -d user -s "${KEYCHAIN_PATH}" $EXISTING
fi

OPENSSL=/usr/bin/openssl
if [[ -x /opt/homebrew/bin/openssl ]]; then OPENSSL=/opt/homebrew/bin/openssl; fi

WORK=$(mktemp -d)
trap "rm -rf '$WORK'" EXIT
cd "$WORK"

echo "▸ Generating self-signed certificate '${CERT_CN}'…"
"$OPENSSL" genrsa -out key.pem 2048 2>/dev/null
"$OPENSSL" req -new -x509 -key key.pem -out cert.pem -days 3650 \
    -subj "/CN=${CERT_CN}" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:FALSE" \
    2>/dev/null

# PKCS12 bundle for keychain import; LibreSSL on macOS needs -legacy.
"$OPENSSL" pkcs12 -export -inkey key.pem -in cert.pem -out cert.p12 \
    -legacy -passout pass:vt -name "${CERT_CN}" 2>/dev/null || \
"$OPENSSL" pkcs12 -export -inkey key.pem -in cert.pem -out cert.p12 \
    -passout pass:vt -name "${CERT_CN}" 2>/dev/null

echo "▸ Importing into ${KEYCHAIN_NAME}…"
security import cert.p12 -k "${KEYCHAIN_PATH}" -P vt -A \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null

# Empty keychain password — set-key-partition-list runs silently.
security set-key-partition-list \
    -S "apple-tool:,apple:,codesign:" \
    -s -k "" "${KEYCHAIN_PATH}" >/dev/null

# Mark cert as trusted for code signing (user trust db; no admin needed).
# Without this, find-identity treats the cert as untrusted and codesign refuses.
security add-trusted-cert -p codeSign -k "${KEYCHAIN_PATH}" cert.pem >/dev/null 2>&1 || true

cd - >/dev/null
rm -rf "$WORK"

echo
echo "✅ Installed '${CERT_CN}' into ${KEYCHAIN_NAME} (no password)."
echo
security find-identity -p codesigning -v "${KEYCHAIN_PATH}" | grep -F "${CERT_CN}"
echo
echo "build-app.sh will now sign with this cert silently."
