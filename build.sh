#!/bin/bash
set -e

# ============================================================
# 剥香蕉 Build Script
# Compiles the app, creates .app bundle, signs, and builds DMG
# ============================================================

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
BINARY_NAME="FocusGuard"
APP_NAME="剥香蕉"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="剥香蕉-1.0.0.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "═══════════════════════════════════════"
echo "  剥香蕉 · 专注守护 — 构建脚本"
echo "═══════════════════════════════════════"
echo ""

# Clean
echo "🧹 清理旧构建..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Find all Swift files
SWIFT_FILES=$(find "$PROJECT_DIR/Sources" -name "*.swift" | sort)
echo "📄 Swift 文件:"
for f in $SWIFT_FILES; do
    echo "   - $(basename $f)"
done
echo ""

# Get SDK path
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
echo "🔧 SDK: $SDK_PATH"

# Get architecture
ARCH=$(uname -m)
echo "🔧 架构: $ARCH"
echo ""

# Compile using xcrun swiftc for proper SDK setup
echo "🔨 编译中..."
SDK_FW="$SDK_PATH/System/Library/Frameworks"
xcrun swiftc \
    -o "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Combine \
    -framework CoreGraphics \
    -sdk "$SDK_PATH" \
    -target "$ARCH-apple-macos13.0" \
    -F "$SDK_FW" \
    -Xlinker -rpath -Xlinker /System/Library/Frameworks \
    -Xlinker -rpath -Xlinker /usr/lib \
    -parse-as-library \
    $SWIFT_FILES

echo "✅ 编译成功"
echo ""

# Copy Info.plist
echo "📋 复制资源文件..."
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/FocusGuard.entitlements" "$APP_BUNDLE/Contents/Resources/"

# Generate banana emoji app icon
echo "🎨 生成应用图标..."
ICON_DIR="$BUILD_DIR/icon.iconset"
mkdir -p "$ICON_DIR"

# Step 1: Render banana emoji at 1024x1024 using CoreText (best quality)
EMOJI_MASTER="$BUILD_DIR/emoji_master.png"
RENDER_SRC="$PROJECT_DIR/render_emoji.swift"
RENDER_BIN="$BUILD_DIR/emoji_render"

xcrun swiftc -o "$RENDER_BIN" "$RENDER_SRC" -framework AppKit \
    -sdk "$SDK_PATH" 2>/dev/null && \
    "$RENDER_BIN" 2>/dev/null

# Step 2: Downscale to all required icon sizes
if [ -f "$EMOJI_MASTER" ]; then
    python3 -c "
from PIL import Image
import os
master = Image.open('$EMOJI_MASTER')
out = '$ICON_DIR'
os.makedirs(out, exist_ok=True)
for name, sz in [('16x16',16),('16x16@2x',32),('32x32',32),('32x32@2x',64),
                 ('128x128',128),('128x128@2x',256),('256x256',256),
                 ('256x256@2x',512),('512x512',512),('512x512@2x',1024)]:
    master.resize((sz,sz), Image.LANCZOS).save(os.path.join(out, f'icon_{name}.png'), 'PNG')
print('ok')
" 2>/dev/null && echo "   ✅ Emoji 图标已生成" || echo "   ⚠️ Downscale 失败"
else
    echo "   ⚠️ Emoji 渲染失败，尝试备用方案..."
    python3 "$PROJECT_DIR/generate_icon.py" "$ICON_DIR" 2>/dev/null || {
        for size in 16 32 64 128 256 512; do
            sips -z $size $size -c $size $size --setProperty format png \
                /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns \
                --out "$ICON_DIR/icon_${size}x${size}.png" 2>/dev/null || true
        done
    }
fi

# Step 3: Create .icns
if iconutil -c icns "$ICON_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null; then
    echo "   ✅ 图标已打包"
else
    echo "   ⚠️ 图标打包失败"
fi

# Code sign (ad-hoc)
echo "🔐 代码签名 (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "$PROJECT_DIR/Resources/FocusGuard.entitlements" \
    "$APP_BUNDLE" 2>/dev/null || {
    echo "   ⚠️ 签名失败，跳过（仍可运行）"
}

echo "✅ 签名完成"
echo ""

# Verify the app
echo "🔍 验证应用..."
if [ -f "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME" ]; then
    echo "   ✅ 可执行文件存在"
    BINARY_SIZE=$(du -h "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME" | cut -f1)
    echo "   📦 大小: $BINARY_SIZE"
else
    echo "   ❌ 可执行文件缺失!"
    exit 1
fi

# Create DMG
echo ""
echo "💿 创建 DMG 安装包..."

# Create a temporary directory for DMG contents
DMG_SRC="$BUILD_DIR/dmg_src"
mkdir -p "$DMG_SRC"
cp -R "$APP_BUNDLE" "$DMG_SRC/"

# Create a symlink to /Applications for easy drag-to-install
ln -sf /Applications "$DMG_SRC/Applications"

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_SRC" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    -fs HFS+ \
    "$DMG_PATH"

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ 构建完成!"
echo ""
echo "  📱 App:  $APP_BUNDLE"
echo "  💿 DMG:  $DMG_PATH"
echo ""
echo "  安装方式："
echo "  1. 打开 $DMG_NAME"
echo "  2. 拖动 剥香蕉 到 Applications 文件夹"
echo "  3. 首次启动需授予「辅助功能」权限"
echo "═══════════════════════════════════════"
echo ""

# Optionally open the DMG
if [ "$1" = "--open" ]; then
    open "$BUILD_DIR"
    open "$DMG_PATH"
    echo "📂 已打开构建目录和 DMG"
fi
