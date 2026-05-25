#!/bin/bash
# Reverses scripts/setup-signing.sh.
#
# - Removes the project-local signing keychain (build/voca-signing.keychain-db).
# - Removes any *legacy* signing keychain from older versions of this script
#   that wrote into ~/Library/Keychains/ and modified your user search list.
# - Does NOT touch your login keychain or any other apps' keychain data.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"
PROJECT_KEYCHAIN="${PROJECT_ROOT}/build/voca-signing.keychain-db"
LEGACY_KEYCHAIN="${HOME}/Library/Keychains/voca-signing.keychain-db"

# --------------------------------------------------------------------------
# 1. If a legacy install left voca-signing in the user search list, drop it.
#    (The current setup-signing.sh never adds it there; this is defensive.)
# --------------------------------------------------------------------------
raw=$(security list-keychains -d user | sed -E 's/^[[:space:]]*//' | tr -d '"')
if echo "$raw" | grep -qF "voca-signing.keychain-db"; then
    echo "▸ Removing voca-signing.keychain-db from user keychain search list"
    cleaned=$(echo "$raw" \
        | grep -vF "voca-signing.keychain-db" \
        | grep -vE '^[[:space:]]*$' \
        | grep -vE '^/Users/[^/]+/Library/Keychains$')

    if ! echo "$cleaned" | grep -qF "login.keychain-db"; then
        cleaned=$(printf '%s\n%s\n' "${HOME}/Library/Keychains/login.keychain-db" "$cleaned")
    fi
    if [[ -z "$(echo "$cleaned" | tr -d '[:space:]')" ]]; then
        echo "  ⚠ Refusing to apply an empty search list. Aborting."
        exit 1
    fi

    args=()
    while IFS= read -r p; do
        [[ -n "$p" ]] && args+=("$p")
    done <<< "$cleaned"
    security list-keychains -d user -s "${args[@]}"
fi

# --------------------------------------------------------------------------
# 2. Delete both possible keychain files.
# --------------------------------------------------------------------------
for kc in "${PROJECT_KEYCHAIN}" "${LEGACY_KEYCHAIN}"; do
    if [[ -f "${kc}" ]]; then
        echo "▸ Deleting ${kc}"
        security delete-keychain "${kc}" 2>/dev/null || rm -f "${kc}"
    fi
done

echo
echo "✅ All VOCA signing artefacts removed."
echo "   Your login keychain and other apps' keychain data are untouched."
