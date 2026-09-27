#!/bin/bash
# brand/scripts/make-iconset.sh: renders the icon at every size of the asset catalog, and at 1024 px for the brand.
set -euo pipefail
cd "$(dirname "$0")/../.."
SET=App/Assets.xcassets/AppIcon.appiconset
mkdir -p "$SET"
swiftc -O -o /tmp/souffleur-icon brand/scripts/icon.swift
/tmp/souffleur-icon brand/icon-1024.png 1024
for size in 16 32 128 256 512; do
  /tmp/souffleur-icon "$SET/icon_${size}x${size}.png" "$size"
  /tmp/souffleur-icon "$SET/icon_${size}x${size}@2x.png" $((size * 2))
done
cp ~/islet/App/Assets.xcassets/AppIcon.appiconset/Contents.json "$SET/Contents.json" 2>/dev/null || true
echo "$SET"
