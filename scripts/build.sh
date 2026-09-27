#!/bin/bash
# scripts/build.sh: generates the Xcode project with XcodeGen and builds Souffleur.app into .build/xcode.
#
#   scripts/build.sh [Debug|Release]
#
# Signing: ad hoc by default, with the hardened runtime off. Set SOUFFLEUR_TEAM_ID to your Apple team ID to sign with
# your Apple Development certificate instead.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIGURATION="${1:-Debug}"
case "$CONFIGURATION" in
  Debug|Release) ;;
  *) echo "usage: scripts/build.sh [Debug|Release]" >&2; exit 64 ;;
esac
command -v xcodegen >/dev/null || { echo "XcodeGen is missing: brew install xcodegen" >&2; exit 1; }
xcodegen generate --quiet
SIGNING=(ENABLE_HARDENED_RUNTIME=NO)
if [ -n "${SOUFFLEUR_TEAM_ID:-}" ]; then
  SIGNING=(-allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$SOUFFLEUR_TEAM_ID" CODE_SIGN_IDENTITY="Apple Development")
fi
mkdir -p .build/xcode
LOG=.build/xcode/build.log
xcodebuild -project Souffleur.xcodeproj -scheme Souffleur -configuration "$CONFIGURATION" -destination 'generic/platform=macOS' \
  -derivedDataPath .build/xcode -clonedSourcePackagesDirPath .build/spm ${SIGNING[@]+"${SIGNING[@]}"} build > "$LOG" 2>&1 \
  || { grep -E "error:" "$LOG" | head -20 >&2; tail -n 20 "$LOG" >&2; exit 1; }
APP=".build/xcode/Build/Products/$CONFIGURATION/Souffleur.app"
codesign --verify --strict "$APP"
echo "$APP"
