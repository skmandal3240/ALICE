#!/bin/bash
set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

# ═══════════════════════════════════════════════════════════════════════════
# release.sh — ALICE release pipeline
#
#   1. Archive the app via xcodebuild
#   2. Export signed + notarized .app
#   3. Create DMG with drag-to-Applications
#   4. Notarize DMG with Apple
#   5. Create GitHub Release
#
# Usage:
#   ./scripts/release.sh              Auto-bumps version
#   ./scripts/release.sh 1.1          Sets version to 1.1
#   ./scripts/release.sh 1.1 2        Sets version 1.1, build 2
#
# Prerequisites:
#   - Xcode with Developer ID signing certificate
#   - brew install create-dmg gh
#   - gh auth login
#   - xcrun notarytool store-credentials "AC_PASSWORD"
# ═══════════════════════════════════════════════════════════════════════════

SCHEME="ALICE"
APP_NAME="ALICE"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
GITHUB_REPO="skmandal3240/ALICE"

# ── Version detection ────────────────────────────────────────────────────────

LATEST_TAG=$(gh release view --repo "${GITHUB_REPO}" --json tagName --jq '.tagName' 2>/dev/null || echo "")

if [ -n "$LATEST_TAG" ]; then
    LATEST_VERSION="${LATEST_TAG#v}"
    LATEST_BUILD=$(gh release list --repo "${GITHUB_REPO}" --json tagName --jq 'length' 2>/dev/null || echo "0")
    echo "   Latest: ${LATEST_TAG} (build ${LATEST_BUILD})"
else
    LATEST_VERSION="0.0"
    LATEST_BUILD=0
    echo "   No previous releases — starting fresh"
fi

if [ $# -ge 1 ]; then
    MARKETING_VERSION="$1"
else
    MAJOR=$(echo "$LATEST_VERSION" | cut -d. -f1)
    MINOR=$(echo "$LATEST_VERSION" | cut -d. -f2)
    NEXT_MINOR=$((MINOR + 1))
    if [ "$NEXT_MINOR" -ge 10 ]; then
        MAJOR=$((MAJOR + 1))
        NEXT_MINOR=0
    fi
    MARKETING_VERSION="${MAJOR}.${NEXT_MINOR}"
fi

BUILD_NUMBER=${2:-$((LATEST_BUILD + 1))}
TAG="v${MARKETING_VERSION}"

# ── Safety check ─────────────────────────────────────────────────────────────

if gh release view "${TAG}" --repo "${GITHUB_REPO}" &>/dev/null; then
    echo "❌ Release ${TAG} already exists!"
    exit 1
fi

echo ""
echo "🚀 Releasing ${APP_NAME} v${MARKETING_VERSION} (build ${BUILD_NUMBER})"
read -p "   Proceed? (y/N) " -n 1 -r
echo ""
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

# ── Build ────────────────────────────────────────────────────────────────────

echo "🧹 Cleaning..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${EXPORT_DIR}"

echo "📦 Archiving..."
xcodebuild archive     -scheme "${SCHEME}"     -archivePath "${ARCHIVE_PATH}"     MARKETING_VERSION="${MARKETING_VERSION}"     CURRENT_PROJECT_VERSION="${BUILD_NUMBER}"     2>&1 | tail -5

# ── Export ───────────────────────────────────────────────────────────────────

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

echo "📤 Exporting (signing + notarizing)..."
xcodebuild -exportArchive     -archivePath "${ARCHIVE_PATH}"     -exportPath "${EXPORT_DIR}"     -exportOptionsPlist "${EXPORT_OPTIONS}"     2>&1 | tail -5

# ── DMG ──────────────────────────────────────────────────────────────────────

DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
echo "💿 Creating DMG..."
create-dmg     --volname "${APP_NAME}"     --window-pos 200 120     --window-size 660 400     --icon-size 100     --icon "${APP_NAME}.app" 160 195     --app-drop-link 500 195     "${DMG_PATH}"     "${EXPORT_DIR}/${APP_NAME}.app"     2>&1 | tail -3

# ── Notarize DMG ─────────────────────────────────────────────────────────────

echo "🔏 Notarizing DMG..."
xcrun notarytool submit "${DMG_PATH}" --keychain-profile "AC_PASSWORD" --wait
xcrun stapler staple "${DMG_PATH}"

# ── GitHub Release ───────────────────────────────────────────────────────────

echo "🏷️  Creating GitHub Release ${TAG}..."
gh release create "${TAG}" "${DMG_PATH}"     --repo "${GITHUB_REPO}"     --title "v${MARKETING_VERSION}"     --notes "ALICE v${MARKETING_VERSION}"     --latest

echo ""
echo "✅ Release ${TAG} complete!"
echo "   https://github.com/${GITHUB_REPO}/releases/tag/${TAG}"
