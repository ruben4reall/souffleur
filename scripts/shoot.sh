#!/bin/bash
# scripts/shoot.sh <name> <seconds> <args...>: launches the Debug app with arguments, waits, and photographs its
# windows (the prompter panel as <name>.png, any other window as <name>-window.png) into .build/shots.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="$1"; WAIT="$2"; shift 2
APP=.build/xcode/Build/Products/Debug/Souffleur.app
mkdir -p .build/shots
[ -x .build/window-id ] || swiftc -O -o .build/window-id scripts/window-id.swift
pkill -x Souffleur 2>/dev/null || true; sleep 0.6
("$APP/Contents/MacOS/Souffleur" -SouffleurSkipWelcome YES -hiddenFromCapture NO -AppleLanguages '(en)' -AppleLocale en_US "$@" >/dev/null 2>&1 &)
sleep "$WAIT"
while read -r id x y w h layer rest; do
  [ -z "$id" ] && continue
  if [ "$layer" != "0" ]; then screencapture -x -o -l "$id" ".build/shots/$NAME.png"; else screencapture -x -o -l "$id" ".build/shots/$NAME-window.png"; fi
done < <(.build/window-id Souffleur all)
ls .build/shots | grep "^$NAME" || true
