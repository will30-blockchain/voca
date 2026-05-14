#!/bin/bash
# Wipes TCC entries for VOCA so macOS re-prompts on next launch.
# Useful when the app was rebuilt under different signatures and the
# old grants are orphaned.
set -euo pipefail

BUNDLE_ID="com.voca.app"

echo "▸ Quitting VOCA (if running)…"
pkill -f "VOCA.app/Contents/MacOS/VOCA" 2>/dev/null || true
sleep 0.4

echo "▸ Resetting TCC permissions for ${BUNDLE_ID}…"
tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset Microphone "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset SpeechRecognition "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset AppleEvents "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset ListenEvent "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset PostEvent "${BUNDLE_ID}" 2>/dev/null || true

echo "✅ TCC cleared. Relaunch VOCA:"
echo "    open dist/VOCA.app"
echo
echo "macOS will re-prompt for Microphone and Accessibility. Grant both."
