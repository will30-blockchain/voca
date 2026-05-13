#!/bin/bash
# Wipes TCC entries for VoiceType so macOS re-prompts on next launch.
# Useful when the app was rebuilt under different signatures and the
# old grants are orphaned.
set -euo pipefail

BUNDLE_ID="com.voicetype.app"

echo "▸ Quitting VoiceType (if running)…"
pkill -f "VoiceType.app/Contents/MacOS/VoiceType" 2>/dev/null || true
sleep 0.4

echo "▸ Resetting TCC permissions for ${BUNDLE_ID}…"
tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset Microphone "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset SpeechRecognition "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset AppleEvents "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset ListenEvent "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset PostEvent "${BUNDLE_ID}" 2>/dev/null || true

echo "✅ TCC cleared. Relaunch VoiceType:"
echo "    open /Users/will77/Documents/VoiceType/dist/VoiceType.app"
echo
echo "macOS will re-prompt for Microphone and Accessibility. Grant both."
