#!/bin/bash
# Standalone build: never reads the .xcodeproj, so no project build phases can run.
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SRC="$(cd "$(dirname "$0")" && pwd)/Eagle construction"
OUT="${TMPDIR:-/tmp}/eagle-construction-build"; APP="$OUT/Eagle.app"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
mkdir -p "$APP"
FILES=(); while IFS= read -r f; do FILES+=("$f"); done < <(find "$SRC" -name "*.swift")
FLAGS=(-sdk "$SDK" -target arm64-apple-ios26.2-simulator -swift-version 5 -default-isolation MainActor -D DEBUG
  -enable-upcoming-feature MemberImportVisibility -enable-upcoming-feature InferIsolatedConformances
  -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferSendableFromCaptures
  -enable-upcoming-feature DisableOutwardActorInference -enable-upcoming-feature GlobalActorIsolatedTypesUsability
  -module-name Eagle_construction)
if [ "$1" = "check" ]; then xcrun swiftc -typecheck "${FLAGS[@]}" "${FILES[@]}"; exit 0; fi
xcrun swiftc -Onone -parse-as-library "${FLAGS[@]}" "${FILES[@]}" -o "$APP/Eagle"
xcrun actool "$SRC/Assets.xcassets" --compile "$APP" --platform iphonesimulator --minimum-deployment-target 26.2 --target-device iphone --output-format human-readable-text --app-icon AppIcon --accent-color AccentColor --output-partial-info-plist "$OUT/assets.plist" >/dev/null
cat > "$APP/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.Eagle-construction</string><key>CFBundleExecutable</key><string>Eagle</string><key>CFBundleName</key><string>Eagle</string>
<key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>1.0</string><key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>26.2</string><key>UILaunchScreen</key><dict/><key>UIDeviceFamily</key><array><integer>1</integer></array>
<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><true/></dict>
<key>NSLocationWhenInUseUsageDescription</key><string>Eagle Jobs uses your location to match you with nearby jobs and workers, and to share your arrival on a booking.</string>
<key>NSCameraUsageDescription</key><string>Eagle Jobs uses the camera to send photos in chat.</string>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
<key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array><key>DTPlatformName</key><string>iphonesimulator</string>
</dict></plist>
PL
/usr/libexec/PlistBuddy -c "Merge $OUT/assets.plist" "$APP/Info.plist" >/dev/null
codesign -f -s - "$APP" >/dev/null 2>&1
echo built "$APP"
D=$(xcrun simctl list devices available | grep -m1 "iPhone 17 Pro (" | grep -oE "[0-9A-F-]{36}")
xcrun simctl boot "$D" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$D" -b >/dev/null
xcrun simctl install "$D" "$APP"
xcrun simctl launch "$D" com.Eagle-construction "$@"
