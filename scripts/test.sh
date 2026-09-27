#!/bin/bash
# scripts/test.sh: runs the SouffleurKit tests, sharing the Xcode build's module cache so the tests take little disk.
set -euo pipefail
cd "$(dirname "$0")/.."
CACHE="$PWD/.build/xcode/ModuleCache.noindex"
mkdir -p "$CACHE"
swift test --package-path Packages/SouffleurKit --scratch-path .build/spm-tests \
  -Xswiftc -module-cache-path -Xswiftc "$CACHE" -Xcc -fmodules-cache-path="$CACHE" "$@"
