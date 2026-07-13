#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# build-installer.sh — Build ALICE and create a macOS installer DMG
#
# Usage:
#   ./scripts/build-installer.sh              Build + DMG (unsigned, local use)
#   ./scripts/build-installer.sh --signed     Build + sign + notarize DMG
#   ./scripts/build-installer.sh --clean      Clean build + DMG
#
# Prerequisites:
#   - macOS 14.2+ (Sonoma or later)
#   - Xcode 16+ with Command Line Tools
#   - XcodeGen: brew install xcodegen
#   - create-dmg: brew install create-dmg
#   - For signing: Apple Developer ID certificate in Keychain
# ═══════════════════════════════════════════════════════════════════════════

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="ALICE"
SCHEME="ALICE"
APP_BUNDLE="${APP_NAME}.app"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"

SIGNED=false
CLEAN=false

for arg in "$@"; do
    case $arg in
        --signed) SIGNED=true ;;
        --clean)  CLEAN=true ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          ALICE Installer Builder                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Pre-flight checks
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ This script must run on macOS."
    exit 1
fi

if ! xcode-select -p &>/dev/null; then
    echo "❌ Xcode Command Line Tools not found. Install with: xcode-select --install"
    exit 1
fi

if ! command -v xcodegen &>/dev/null; then
    echo "📦 Installing XcodeGen..."
    brew install xcodegen
fi

if ! command -v create-dmg &>/dev/null; then
    echo "📦 Installing create-dmg..."
    brew install create-dmg
fi

# Step 1: Generate Xcode project
echo "🔧 Generating Xcode project..."
cd "${PROJECT_DIR}"
xcodegen generate 2>&1 | tail -3

# Step 2: Clean if requested
if $CLEAN; then
    echo "🧹 Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}" "${EXPORT_DIR}"

# Step 3: Build the app
echo ""
if $SIGNED; then
    echo "📦 Archiving (signed)..."
    xcodebuild archive \
        -scheme "${SCHEME}" \
        -archivePath "${ARCHIVE_PATH}" \
        -configuration Release \
        CODE_SIGN_STYLE="Automatic" \
        2>&1 | tail -10
    BUILT_APP="${ARCHIVE_PATH}/Products/Applications/${APP_BUNDLE}"
else
    echo "📦 Building (unsigned — for local use)..."
    xcodebuild build \
        -scheme "${SCHEME}" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tail -10
    BUILT_APP=$(find "${BUILD_DIR}/DerivedData" -name "${APP_BUNDLE}" -type d 2>/dev/null | head -1)
fi

if [[ -z "${BUILT_APP}" || ! -d "${BUILT_APP}" ]]; then
    echo ""
    echo "❌ Build failed — ${APP_BUNDLE} not found."
    echo "   Check the build output above for errors."
    exit 1
fi

echo "✅ Build succeeded: ${BUILT_APP}"

# Step 4: Export (if signed)
if $SIGNED; then
    echo ""
    echo "📤 Exporting signed app..."
    EXPORT_OPTIONS="${BUILD_DIR}/ExportOptions.plist"
    cat > "${EXPORT_OPTIONS}" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST
    xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_PATH}" \
        -exportPath "${EXPORT_DIR}" \
        -exportOptionsPlist "${EXPORT_OPTIONS}" \
        2>&1 | tail -5
    BUILT_APP="${EXPORT_DIR}/${APP_BUNDLE}"
fi

if [[ ! -d "${BUILT_APP}" ]]; then
    echo "❌ App not found after export."
    exit 1
fi

# Step 5: Create DMG installer
echo ""
echo "💿 Creating DMG installer..."
rm -f "${DMG_PATH}"

create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 100 \
    --icon "${APP_BUNDLE}" 160 195 \
    --app-drop-link 500 195 \
    --hide-extension "${APP_BUNDLE}" \
    "${DMG_PATH}" \
    "${BUILT_APP}" \
    2>&1 | tail -5

if [[ ! -f "${DMG_PATH}" ]]; then
    echo "❌ DMG creation failed."
    exit 1
fi

echo "✅ DMG created: ${DMG_PATH}"

# Step 6: Notarize (if signed)
if $SIGNED; then
    echo ""
    echo "🔏 Notarizing DMG with Apple..."
    if ! xcrun notarytool history --keychain-profile "AC_PASSWORD" &>/dev/null; then
        echo "⚠️  Notarization credentials not set up."
        echo "   Run: xcrun notarytool store-credentials 'AC_PASSWORD'"
        echo "   Skipping notarization."
    else
        xcrun notarytool submit "${DMG_PATH}" \
            --keychain-profile "AC_PASSWORD" \
            --wait 2>&1 | tail -5
        echo "📎 Stapling notarization ticket..."
        xcrun stapler staple "${DMG_PATH}" 2>&1
        echo "✅ DMG notarized and stapled"
    fi
fi

# Step 7: Summary
DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ ALICE Installer Built Successfully                        ║"
echo "║                                                              ║"
echo "║  DMG:    ${DMG_PATH}"
echo "║  Size:   ${DMG_SIZE}"
echo "║  Signed: $(${SIGNED} && echo 'Yes' || echo 'No (unsigned — local use only)')"
echo "║                                                              ║"
echo "║  To install: Double-click the DMG, drag ALICE to Applications ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

open "${DMG_PATH}"