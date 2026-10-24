#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
out="${1:-dist}"
arch="$(uname -m)"
mkdir -p "$out" build
python3 extract_yuzu.py
python3 make_xbox_preview.py
python3 make_mobapad_preview.py
out="${out:A}"
stage="$(mktemp -d /private/tmp/controllerdesk-package.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
app="$stage/Controller Desk.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -target "$arch-apple-macos14.0" -c Sources/HIDBridge.m -o build/HIDBridge.o
xcrun swiftc -swift-version 5 -warnings-as-errors -O -target "$arch-apple-macosx14.0" -import-objc-header Sources/HIDBridge.h Sources/Core.swift Sources/Model.swift Sources/ControllerDrawing.swift Sources/YuzuPreview.swift Sources/FastControllerView.swift Sources/FastPlots.swift Sources/RealtimeTrigger.swift Sources/XboxPreview.swift Sources/Views.swift Sources/App.swift build/HIDBridge.o -framework SwiftUI -framework AppKit -framework GameController -framework CoreBluetooth -framework IOKit -framework WebKit -o "$app/Contents/MacOS/ControllerDesk"
cp Resources/controllers.json "$app/Contents/Resources/"
blueutil_root="$(brew --prefix blueutil)"
install -m 755 "$blueutil_root/bin/blueutil" "$app/Contents/Resources/blueutil"
cp "$blueutil_root/LICENSE.txt" "$app/Contents/Resources/blueutil-LICENSE.txt"
cp Resources/References.md "$app/Contents/Resources/"
cp Resources/yuzu-vectors.json "$app/Contents/Resources/"
cp Resources/xbox-preview.html Resources/mobapad-preview.html Resources/mobapad-m6-hd.svg "$app/Contents/Resources/"
cp Vendor/GamepadAssetPack/LICENSE "$app/Contents/Resources/Xbox-Artwork-LICENSE.txt"
cp LICENSE "$app/Contents/Resources/GPL-3.0.txt"
chmod 600 "$app/Contents/Resources/controllers.json"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.xiuxiua8.ControllerDesk</string>
<key>CFBundleName</key><string>Controller Desk</string>
<key>CFBundleDisplayName</key><string>Controller Desk</string>
<key>CFBundleExecutable</key><string>ControllerDesk</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.1</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSBluetoothAlwaysUsageDescription</key><string>用于连接你已登记的手柄，并读取按键与体感数据。</string>
<key>NSHumanReadableCopyright</key><string>ControllerDesk 2026. Bundled blueutil under MIT license.</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$app/Contents/Resources/"; fi
codesign --force --sign - --identifier io.github.xiuxiua8.ControllerDesk.blueutil "$app/Contents/Resources/blueutil"
# Finder may attach presentation metadata to bundles in a File Provider folder.
# Remove only FinderInfo, never quarantine or security attributes.
xattr -d com.apple.FinderInfo "$app" 2>/dev/null || true
for attempt in 1 2 3; do
    xattr -d com.apple.FinderInfo "$app" 2>/dev/null || true
    if codesign --force --sign - --identifier io.github.xiuxiua8.ControllerDesk "$app"; then break; fi
    if (( attempt == 3 )); then exit 1; fi
done
codesign --verify --deep --strict "$app"
ditto --norsrc --noextattr "$app" "$out/Controller Desk.app"
ditto --norsrc --noextattr -c -k --keepParent "$app" "$out/Controller Desk.zip"
xattr -d com.apple.FinderInfo "$out/Controller Desk.app" 2>/dev/null || true
print "Built and signature verified: $out/Controller Desk.app"
