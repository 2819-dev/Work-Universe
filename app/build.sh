#!/bin/bash
# Builds "Snippet Menu.app" and Snippet-Menu.zip. Must run on a Mac
# (GitHub Actions does this automatically; see .github/workflows/build.yml).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-0.0.0}"
OUT=build
APP="$OUT/Snippet Menu.app"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "== Testing the snippet library"
swiftc Sources/SnippetParser.swift Tests/main.swift -o "$OUT/tests"
"$OUT/tests" Resources/starter-snippets.txt

echo "== Compiling (Apple Silicon + Intel)"
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" Sources/*.swift -o "$OUT/SnippetMenu-$arch"
done
lipo -create "$OUT/SnippetMenu-arm64" "$OUT/SnippetMenu-x86_64" -output "$APP/Contents/MacOS/SnippetMenu"

sed "s/__VERSION__/$VERSION/g" Info.plist > "$APP/Contents/Info.plist"
cp Resources/starter-snippets.txt "$APP/Contents/Resources/starter-snippets.txt"

echo "== Making the icon"
swiftc Tools/make-icon.swift -o "$OUT/make-icon"
"$OUT/make-icon" "$OUT/icon.png"
ICONSET="$OUT/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$OUT/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$OUT/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "== Signing (free ad-hoc signature, no Apple Developer account)"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP"

echo "== Zipping"
PACKAGE="$OUT/package/Snippet Menu"
mkdir -p "$PACKAGE"
cp -R "$APP" "$PACKAGE/"
cp "How to install.txt" "$PACKAGE/"
ditto -c -k --keepParent "$PACKAGE" "$OUT/Snippet-Menu.zip"
echo "Built $OUT/Snippet-Menu.zip (version $VERSION)"
