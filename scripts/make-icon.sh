#!/bin/bash
# Build VOCA.icns from Resources/logo.png. The .icns is committed to
# Resources/ and consumed by build-app.sh which copies it into the bundle.
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="Resources/logo.png"
ICONSET="Resources/VOCA.iconset"
OUT="Resources/VOCA.icns"

if [[ ! -f "${SRC}" ]]; then
    echo "❌ Missing ${SRC}. Re-run logo generation first." >&2
    exit 1
fi

rm -rf "${ICONSET}"
mkdir -p "${ICONSET}"

# macOS expects these specific sizes for a complete .icns.
sips -z 16   16   "${SRC}" --out "${ICONSET}/icon_16x16.png"     >/dev/null
sips -z 32   32   "${SRC}" --out "${ICONSET}/icon_16x16@2x.png"  >/dev/null
sips -z 32   32   "${SRC}" --out "${ICONSET}/icon_32x32.png"     >/dev/null
sips -z 64   64   "${SRC}" --out "${ICONSET}/icon_32x32@2x.png"  >/dev/null
sips -z 128  128  "${SRC}" --out "${ICONSET}/icon_128x128.png"   >/dev/null
sips -z 256  256  "${SRC}" --out "${ICONSET}/icon_128x128@2x.png">/dev/null
sips -z 256  256  "${SRC}" --out "${ICONSET}/icon_256x256.png"   >/dev/null
sips -z 512  512  "${SRC}" --out "${ICONSET}/icon_256x256@2x.png">/dev/null
sips -z 512  512  "${SRC}" --out "${ICONSET}/icon_512x512.png"   >/dev/null
cp "${SRC}"             "${ICONSET}/icon_512x512@2x.png"

iconutil -c icns "${ICONSET}" -o "${OUT}"
rm -rf "${ICONSET}"

echo "✅ ${OUT}"
