#!/usr/bin/env bash
# Build Heat.app (ad-hoc signed) and a zip for GitHub Releases.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Heat.app"
MACOS_MIN="${MACOS_MIN:-14.0}"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos${MACOS_MIN}"

echo "==> Cleaning dist"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Compiling heat-sampler"
swiftc \
  -parse-as-library \
  -O \
  -target "$TARGET" \
  -sdk "$(xcrun --show-sdk-path)" \
  -o "$APP/Contents/Resources/heat-sampler" \
  "$ROOT/helper/main.swift"

echo "==> Compiling Heat"
SOURCES=()
while IFS= read -r f; do
  SOURCES+=("$f")
done < <(find "$ROOT/Sources/Heat" -name '*.swift' | sort)

if [[ ${#SOURCES[@]} -eq 0 ]]; then
  echo "No Swift sources found under Sources/Heat" >&2
  exit 1
fi

swiftc \
  -parse-as-library \
  -O \
  -target "$TARGET" \
  -sdk "$(xcrun --show-sdk-path)" \
  -framework AppKit \
  -framework SwiftUI \
  -framework Foundation \
  -o "$APP/Contents/MacOS/Heat" \
  "${SOURCES[@]}"

echo "==> Bundling resources"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/dev.heat.sampler.plist" "$APP/Contents/Resources/dev.heat.sampler.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Ad-hoc codesign"
codesign --force --sign - "$APP/Contents/Resources/heat-sampler"
codesign --force --deep --sign - "$APP"

echo "==> Verify"
codesign -dv --verbose=2 "$APP" 2>&1 | head -20
plutil -lint "$APP/Contents/Info.plist"

ZIP="$DIST/Heat-macos.zip"
echo "==> Zip $ZIP"
(
  cd "$DIST"
  rm -f Heat-macos.zip
  zip -r -y Heat-macos.zip Heat.app
)

echo ""
echo "Built: $APP"
echo "Zip:   $ZIP"
echo ""
echo "Install: unzip and drag Heat.app to /Applications"
echo "Gatekeeper: xattr -dr com.apple.quarantine /Applications/Heat.app"
