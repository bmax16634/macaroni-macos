#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${1:-debug}"
signing_identity="${MACARONI_SIGNING_IDENTITY:--}"

case "$configuration" in
  debug|release) ;;
  *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;;
esac

cd "$project_root"
swift build -c "$configuration" --arch arm64

case "$configuration" in
  debug) xcode_configuration="Debug" ;;
  release) xcode_configuration="Release" ;;
esac

extension_build_root="$project_root/.build/finder-extension"
xcodebuild \
  -project "$project_root/FinderExtension/MacaroniFinderExtension.xcodeproj" \
  -target MacaroniFinderExtension \
  -configuration "$xcode_configuration" \
  SYMROOT="$extension_build_root" \
  OBJROOT="$extension_build_root/Intermediates" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  build

binary_path="$(swift build -c "$configuration" --arch arm64 --show-bin-path)/Macaroni"
extension_path="$extension_build_root/$xcode_configuration/MacaroniFinderExtension.appex"
app_path="$project_root/build/Macaroni.app"
contents_path="$app_path/Contents"

if [[ "$app_path" != "$project_root/build/Macaroni.app" ]]; then
  echo "Refusing to replace unexpected app path: $app_path" >&2
  exit 1
fi
rm -rf "$app_path"
mkdir -p "$contents_path/MacOS" "$contents_path/Resources" "$contents_path/PlugIns"
cp "$binary_path" "$contents_path/MacOS/Macaroni"
cp "$project_root/Resources/Info.plist" "$contents_path/Info.plist"
cp "$project_root/Resources/Macaroni.icns" "$contents_path/Resources/Macaroni.icns"
cp "$project_root/LICENSE" "$contents_path/Resources/GPL-3.0.txt"
ditto "$extension_path" "$contents_path/PlugIns/MacaroniFinderExtension.appex"
codesign \
  --force \
  --sign "$signing_identity" \
  --entitlements "$project_root/FinderExtension/MacaroniFinderExtension/MacaroniFinderExtension.entitlements" \
  "$contents_path/PlugIns/MacaroniFinderExtension.appex"
codesign --force --sign "$signing_identity" "$app_path"

echo "$app_path"
