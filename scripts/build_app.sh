#!/bin/bash
# 构建循迹 StreakJournal.app（仅 Apple Silicon）
# 用法: ./scripts/build_app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="StreakJournal"
APP_DISPLAY_NAME="循迹"
BUNDLE_ID="com.edy.streakjournal"
VERSION="1.9.13"
ROOT="$(pwd)"
BUILD="$ROOT/build"
RESOURCE_SHADOW="$ROOT/.build/toolchain/usr/lib/swift"
SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macosx14.0"

echo "==> 编译（arm64, macOS 14+）"
mkdir -p "$BUILD" "$ROOT/.build/app"

SRCS=$(find "$ROOT/Sources/StreakJournal" -name '*.swift' | sort)
BIN="$ROOT/.build/app/$APP_NAME"

# 优先使用 SwiftPM（完整 Xcode 环境 / GitHub Actions）；
# 若 manifest 工具链损坏（部分 Command Line Tools 安装），回退到 swiftc 直编。
if swift build -c release --arch arm64 >/dev/null 2>&1 && [ -f "$ROOT/.build/release/$APP_NAME" ]; then
    echo "    使用 SwiftPM 构建"
    cp "$ROOT/.build/release/$APP_NAME" "$BIN"
else
    echo "    使用 swiftc 直编（含本地资源目录影子修复）"
    swiftc -Onone -parse-as-library \
        -resource-dir "$RESOURCE_SHADOW" \
        -target "$TARGET" -sdk "$SDK" \
        $SRCS \
        -o "$BIN"
fi

echo "==> 生成图标（来自 SVG，NSImage 原生渲染）"
ICON_PNG="$ROOT/.build/app/AppIcon_1024.png"
MENU_ICON="$ROOT/.build/app/MenuBarIcon.png"
SVG_SRC="$ROOT/Resources/AppIconSource.svg"
if [ ! -f "$ICON_PNG" ] || [ ! -f "$MENU_ICON" ]; then
    if swift build -c release --arch arm64 >/dev/null 2>&1; then
        swift tools/composite_icon.swift "$SVG_SRC" "$ICON_PNG" "$MENU_ICON" || true
    else
        swift -resource-dir "$RESOURCE_SHADOW" tools/composite_icon.swift "$SVG_SRC" "$ICON_PNG" "$MENU_ICON" || true
    fi
    # SVG 解析失败时回退到内置对勾图标
    if [ ! -f "$ICON_PNG" ]; then
        echo "    SVG 渲染失败，回退到内置对勾图标"
        if swift build -c release --arch arm64 >/dev/null 2>&1; then
            swift tools/make_icon.swift "$ICON_PNG"
        else
            swift -resource-dir "$RESOURCE_SHADOW" tools/make_icon.swift "$ICON_PNG"
        fi
    fi
fi
ICONSET="$ROOT/.build/app/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for spec in "512 512 icon_512x512" "256 256 icon_256x256" "128 128 icon_128x128" "64 64 icon_32x32@2x" "32 32 icon_32x32" "16 16 icon_16x16"; do
    set -- $spec
    sips -z $1 $2 "$ICON_PNG" --out "$ICONSET/$3.png" >/dev/null
done
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
ICNS="$ROOT/.build/app/AppIcon.icns"
iconutil -c icns "$ICONSET" -o "$ICNS"

echo "==> 组装 $APP_NAME.app"
APP="$BUILD/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/app/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"
if [ -f "$MENU_ICON" ]; then
    cp "$MENU_ICON" "$APP/Contents/Resources/MenuBarIcon.png"
fi

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>循迹 · 个人坚持记录工具</string>
</dict>
</plist>
PLIST

cat > "$APP/Contents/PkgInfo" << PKG
APPL????
PKG

echo "==> Ad-hoc 签名（本地运行用；正式发布前请用 Developer ID 签名）"
codesign --force --sign - "$APP"

echo "==> 完成: $APP"
file "$APP/Contents/MacOS/$APP_NAME"
