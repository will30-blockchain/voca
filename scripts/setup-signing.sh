#!/bin/bash
# Creates a *project-local* self-signed code-signing certificate so that
# repeated builds keep the same signing identity — macOS TCC then remembers
# Microphone / Accessibility grants across rebuilds.
#
# Open-source contract:
#   - This script is opt-in. Plain `swift build` works without it.
#   - It only writes inside this project directory (build/...).
#   - It does NOT modify your user keychain search list.
#   - It does NOT touch your login keychain.
#   - To remove every trace it ever created, run scripts/uninstall-signing.sh.
#
# History note:
#   Earlier versions of this script (pre-2026-05) created the keychain at
#   ~/Library/Keychains/voca-signing.keychain-db AND inserted it into the
#   user-wide keychain search list. That caused other apps (NordPass, etc.)
#   to fail keychain writes whenever the signing keychain auto-locked. This
#   script now detects that legacy state and cleans it up automatically.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

CERT_CN="VOCA Dev"
BUILD_DIR="${PROJECT_ROOT}/build"
KEYCHAIN_PATH="${BUILD_DIR}/voca-signing.keychain-db"
# Local, non-sensitive password — the keychain only holds a self-signed dev cert.
KEYCHAIN_PASS="voca"
LEGACY_KEYCHAIN="${HOME}/Library/Keychains/voca-signing.keychain-db"

# --------------------------------------------------------------------------
# Migration: clean up any state created by older versions of this script.
# --------------------------------------------------------------------------
clean_legacy_search_list() {
    local raw cleaned p
    raw=$(security list-keychains -d user | sed -E 's/^[[:space:]]*//' | tr -d '"')
    if ! echo "$raw" | grep -qF "voca-signing.keychain-db"; then
        return 0
    fi
    echo "▸ Detected legacy voca-signing keychain in your user search list — removing it."
    echo "  (Older versions of setup-signing.sh did this. It could break other"
    echo "   apps' keychain writes when the signing keychain auto-locked.)"

    # Drop the voca-signing entry plus any malformed phantom directory entry
    # the old script's sed/tr left behind.
    cleaned=$(echo "$raw" \
        | grep -vF "voca-signing.keychain-db" \
        | grep -vE '^[[:space:]]*$' \
        | grep -vE '^/Users/[^/]+/Library/Keychains$')

    # Defensive: never leave the search list without login.keychain-db.
    if ! echo "$cleaned" | grep -qF "login.keychain-db"; then
        cleaned=$(printf '%s\n%s\n' "${HOME}/Library/Keychains/login.keychain-db" "$cleaned")
    fi
    if [[ -z "$(echo "$cleaned" | tr -d '[:space:]')" ]]; then
        echo "  ⚠ Refusing to apply an empty search list. Aborting cleanup."
        return 0
    fi

    local args=()
    while IFS= read -r p; do
        [[ -n "$p" ]] && args+=("$p")
    done <<< "$cleaned"
    security list-keychains -d user -s "${args[@]}"
}

clean_legacy_search_list

if [[ -f "${LEGACY_KEYCHAIN}" ]]; then
    echo "▸ Deleting legacy keychain file at ${LEGACY_KEYCHAIN}"
    security delete-keychain "${LEGACY_KEYCHAIN}" 2>/dev/null || rm -f "${LEGACY_KEYCHAIN}"
fi

# --------------------------------------------------------------------------
# Fast path: already set up.
# --------------------------------------------------------------------------
if [[ -f "${KEYCHAIN_PATH}" ]] && \
   security find-identity -p codesigning -v "${KEYCHAIN_PATH}" 2>/dev/null \
     | grep -qF "\"${CERT_CN}\""; then
    echo "✓ Code-signing identity '${CERT_CN}' already present in build/voca-signing.keychain-db."
    exit 0
fi

# --------------------------------------------------------------------------
# Create the project-local keychain.
# --------------------------------------------------------------------------
mkdir -p "${BUILD_DIR}"
rm -f "${KEYCHAIN_PATH}"

echo "▸ Creating project-local keychain at build/voca-signing.keychain-db"
security create-keychain -p "${KEYCHAIN_PASS}" "${KEYCHAIN_PATH}"
security unlock-keychain -p "${KEYCHAIN_PASS}" "${KEYCHAIN_PATH}"
security set-keychain-settings "${KEYCHAIN_PATH}"

OPENSSL=/usr/bin/openssl
if [[ -x /opt/homebrew/bin/openssl ]]; then OPENSSL=/opt/homebrew/bin/openssl; fi

WORK=$(mktemp -d)
trap "rm -rf '$WORK'" EXIT
cd "$WORK"

echo "▸ Generating self-signed certificate '${CERT_CN}'"
"$OPENSSL" genrsa -out key.pem 2048 2>/dev/null
"$OPENSSL" req -new -x509 -key key.pem -out cert.pem -days 3650 \
    -subj "/CN=${CERT_CN}" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:FALSE" \
    2>/dev/null

"$OPENSSL" pkcs12 -export -inkey key.pem -in cert.pem -out cert.p12 \
    -legacy -passout pass:vt -name "${CERT_CN}" 2>/dev/null || \
"$OPENSSL" pkcs12 -export -inkey key.pem -in cert.pem -out cert.p12 \
    -passout pass:vt -name "${CERT_CN}" 2>/dev/null

echo "▸ Importing certificate into project keychain"
security import cert.p12 -k "${KEYCHAIN_PATH}" -P vt -A \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null

security set-key-partition-list \
    -S "apple-tool:,apple:,codesign:" \
    -s -k "${KEYCHAIN_PASS}" "${KEYCHAIN_PATH}" >/dev/null

# Trust the cert for code signing — written into the project keychain itself,
# NOT into the user-wide trust db.
security add-trusted-cert -p codeSign -k "${KEYCHAIN_PATH}" cert.pem >/dev/null 2>&1 || true

cd "${PROJECT_ROOT}"
rm -rf "$WORK"

echo
echo "✅ Installed '${CERT_CN}' into build/voca-signing.keychain-db"
echo "   (Project-local. Not added to your user keychain search list.)"
echo
security find-identity -p codesigning -v "${KEYCHAIN_PATH}" | grep -F "${CERT_CN}" || true
echo
echo "build-app.sh will now sign with this cert silently."
