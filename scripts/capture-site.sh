#!/bin/bash
# scripts/capture-site.sh: photographs the real app for the website and the README. Nothing is drawn by hand: each
# picture is Souffleur itself, in English, reading its own welcome script through the demo switches (no microphone,
# none of the user's scripts). The notch prompter is laid on a real macOS desktop (SOUFFLEUR_DESKTOP, a 3024 x 1964
# PNG) by the website's CSS, and composed for the README by scripts/compose.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=.build/site-shots
mkdir -p "$OUT" site/assets/notch site/assets/app docs/images
[ -d .build/xcode/Build/Products/Debug/Souffleur.app ] || scripts/build.sh >/dev/null
[ -x .build/window-id ] || swiftc -O -o .build/window-id scripts/window-id.swift
[ -x .build/compose ] || swiftc -O -o .build/compose scripts/compose.swift
APP=.build/xcode/Build/Products/Debug/Souffleur.app/Contents/MacOS/Souffleur

run() { pkill -x Souffleur 2>/dev/null || true; sleep 0.8; ("$APP" -SouffleurSkipWelcome YES -hiddenFromCapture NO -AppleLanguages '(en)' -AppleLocale en_US "$@" >/dev/null 2>&1 &) }
panel() { .build/window-id Souffleur panel | head -1 | cut -d' ' -f1; }
window() { .build/window-id Souffleur window | awk -v w="$1" '$6==0 && (w=="" || $4==w)' | head -1 | cut -d' ' -f1; }
shoot_panel() { local id; id=$(panel); [ -n "$id" ] && screencapture -x -o -l "$id" "$OUT/$1.png" && echo "  $1"; }
shoot_window() { local id; id=$(window "${2:-}"); [ -n "$id" ] && screencapture -x -o -l "$id" "$OUT/$1.png" && echo "  $1"; }
# Seconds until the demo has read `word` words: launch, countdown, 0.4 s a word, the glide.
at() { echo "1 + 2.4 + $1 * 0.4 + 1.2" | bc; }

echo "Notch:"
for stop in 4 9 14 19 24 29; do run -SouffleurDemo notch -SouffleurDemoVoice YES -SouffleurDemoStop "$stop"; sleep "$(at "$stop")"; shoot_panel "read-$stop"; done
for light in violet ocean ember mint gold; do
  run -SouffleurDemo notch -SouffleurDemoVoice YES -SouffleurDemoStop 19 -stageLight "$light"; sleep "$(at 19)"; shoot_panel "light-$light"
done
run -SouffleurDemo notch -SouffleurDemoVoice YES -SouffleurDemoStop 16 -SouffleurDemoHover YES; sleep "$(at 16)"; shoot_panel controls
run -SouffleurDemo notch -SouffleurDemoVoice YES; sleep 2.3; shoot_panel countdown
run -SouffleurDemo notch -SouffleurDemoVoice YES; sleep 58; shoot_panel summary

echo "Cards:"
run -SouffleurDemo floating -SouffleurDemoVoice YES -SouffleurDemoStop 22; sleep "$(at 22)"; shoot_panel floating || true
[ -f "$OUT/floating.png" ] || { id=$(.build/window-id Souffleur all | awk '$6!=0' | head -1 | cut -d' ' -f1); screencapture -x -o -l "$id" "$OUT/floating.png"; echo "  floating"; }
run -SouffleurDemo fullScreen -SouffleurDemoVoice YES -SouffleurDemoStop 22; sleep "$(at 22)"
id=$(.build/window-id Souffleur all | awk '$6!=0' | head -1 | cut -d' ' -f1); screencapture -x -o -l "$id" "$OUT/fullscreen.png"; echo "  fullscreen"

echo "Windows:"
run; sleep 4; osascript -e 'tell application "System Events" to set frontmost of process "Souffleur" to true' >/dev/null 2>&1; sleep 1; shoot_window library 1040
for pane in Prompter Voice Controls; do
  osascript -e 'tell application "System Events" to keystroke "," using command down' >/dev/null 2>&1; sleep 1.2
  osascript -e "tell application \"System Events\" to tell process \"Souffleur\" to click button \"$pane\" of toolbar 1 of window 1" >/dev/null 2>&1; sleep 1.2
  id=$(.build/window-id Souffleur window | awk '$6==0 && $7!="Welcome"' | awk '$4==580' | head -1 | cut -d' ' -f1); [ -n "$id" ] && screencapture -x -o -l "$id" "$OUT/settings-$pane.png" && echo "  settings-$pane"
done

echo "Phone remote:"
run -remoteEnabled YES -SouffleurDemo notch -SouffleurDemoVoice YES -SouffleurDemoStop 22; sleep 3
curl -s -o /dev/null "http://127.0.0.1:7575/" || true
TOKEN=$(defaults read ch.rubencatalao.souffleur remoteToken)
sleep "$(at 22)"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=3 \
  --window-size=390,844 --screenshot="$OUT/remote.png" "http://127.0.0.1:7575/?token=$TOKEN" >/dev/null 2>&1 || true
[ -f "$OUT/remote.png" ] && echo "  remote"
pkill -x Souffleur || true

echo "WebP:"
for f in "$OUT"/read-*.png "$OUT"/light-*.png "$OUT"/controls.png "$OUT"/countdown.png "$OUT"/summary.png; do cwebp -quiet -q 92 -alpha_q 100 "$f" -o "site/assets/notch/$(basename "$f" .png).webp"; done
cwebp -quiet -q 90 -alpha_q 100 "$OUT/floating.png" -o site/assets/app/floating.webp
cwebp -quiet -q 86 -resize 1800 0 "$OUT/fullscreen.png" -o site/assets/app/fullscreen.webp
for f in "$OUT"/library.png "$OUT"/settings-*.png; do cwebp -quiet -q 88 "$f" -o "site/assets/app/$(basename "$f" .png | tr '[:upper:]' '[:lower:]').webp"; done
[ -f "$OUT/remote.png" ] && cwebp -quiet -q 88 "$OUT/remote.png" -o site/assets/app/remote.webp
DESKTOP="${SOUFFLEUR_DESKTOP:-}"
if [ -n "$DESKTOP" ]; then
  cwebp -quiet -q 84 -resize 1920 0 "$DESKTOP" -o site/assets/desktop.webp
  cwebp -quiet -q 86 -crop 0 0 3024 1200 "$DESKTOP" -o site/assets/desktop-top.webp
  # The README cannot lay captures on the desktop with CSS: it gets them composed.
  .build/compose "$DESKTOP" "$OUT/read-19.png" "$OUT/readme-notch.png" 560
  cwebp -quiet -q 88 "$OUT/readme-notch.png" -o docs/images/notch.webp
fi
echo "Done: site/assets/{notch,app}, docs/images"
