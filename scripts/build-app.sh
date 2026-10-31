#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
# Keep generated caches inside this project, including on managed computers.
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/module-cache"
swift_options=(--cache-path .build/cache --config-path .build/config --security-path .build/security)
if [[ "${QUICKLAUNCH_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
    swift_options+=(--disable-sandbox)
fi
swift build "${swift_options[@]}" -c release
binary_dir="$(swift build "${swift_options[@]}" -c release --show-bin-path)"
app_dir="$project_dir/dist/QuickLaunch.app"
icon_file="$project_dir/assets/AppIcon.icns"
if [[ ! -f "$icon_file" ]]; then
    icon_source="$project_dir/assets/icon-1024.png"
    if [[ ! -f "$icon_source" ]]; then
        printf 'Missing app icon: provide assets/AppIcon.icns or assets/icon-1024.png\n' >&2
        exit 1
    fi
    icon_set="$project_dir/.build/QuickLaunch.iconset"
    mkdir -p "$icon_set"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$icon_source" --out "$icon_set/icon_${size}x${size}.png" >/dev/null
        retina_size=$((size * 2))
        sips -z "$retina_size" "$retina_size" "$icon_source" --out "$icon_set/icon_${size}x${size}@2x.png" >/dev/null
    done
    icon_file="$project_dir/.build/AppIcon.icns"
    iconutil -c icns "$icon_set" -o "$icon_file"
fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/QuickLaunch" "$app_dir/Contents/MacOS/QuickLaunch"
cp "$icon_file" "$app_dir/Contents/Resources/AppIcon.icns"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>ko</string>
    <key>CFBundleExecutable</key><string>QuickLaunch</string>
    <key>CFBundleIdentifier</key><string>local.quicklaunch.app</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>QuickLaunch</string>
    <key>CFBundleDisplayName</key><string>QuickLaunch</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.3.0</string>
    <key>CFBundleVersion</key><string>5</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
printf '\nBuilt app: %s\n' "$app_dir"
