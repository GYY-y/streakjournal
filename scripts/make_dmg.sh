#!/bin/bash
# 制作 DMG 安装镜像（拖拽安装布局）
# 用法: ./scripts/make_dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="1.0.0"
BUILD="$(pwd)/build"
APP="$BUILD/StreakJournal.app"
DMG="$BUILD/StreakJournal-$VERSION-arm64.dmg"

[ -d "$APP" ] || { echo "错误：先运行 scripts/build_app.sh"; exit 1; }

STAGING="$BUILD/.dmg-src"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> 打包 DMG"
hdiutil create \
    -volname "循迹" \
    -srcfolder "$STAGING" \
    -format UDZO \
    -fs HFS+ \
    -ov "$DMG"

rm -rf "$STAGING"
echo "==> 完成: $DMG"
ls -lh "$DMG"
