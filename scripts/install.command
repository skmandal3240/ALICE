#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# install.command — Double-clickable installer for ALICE
#
# Users double-click this file to install ALICE from the DMG.
# It copies the app to /Applications and launches it.
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

APP_NAME="ALICE"
APP_BUNDLE="${APP_NAME}.app"
APPLICATIONS_DIR="/Applications"
SOURCE_DIR=""

# Find the DMG mount or the app bundle
for dir in /Volumes/${APP_NAME}*; do
    if [[ -d "${dir}/${APP_BUNDLE}" ]]; then
        SOURCE_DIR="${dir}"
        break
    fi
done

# Also check if we're running from the same directory
if [[ -z "${SOURCE_DIR}" && -d "$(dirname "$0")/${APP_BUNDLE}" ]]; then
    SOURCE_DIR="$(dirname "$0")"
fi

if [[ -z "${SOURCE_DIR}" ]]; then
    echo "❌ Could not find ${APP_BUNDLE}"
    echo "   Make sure the DMG is mounted (double-click the .dmg file first)."
    read -p "Press Enter to exit..."
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          ALICE Installer                                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Source:  ${SOURCE_DIR}/${APP_BUNDLE}"
echo "Target: ${APPLICATIONS_DIR}/${APP_BUNDLE}"
echo ""

# Check if already installed
if [[ -d "${APPLICATIONS_DIR}/${APP_BUNDLE}" ]]; then
    echo "⚠️  ${APP_NAME} is already installed."
    read -p "   Replace existing installation? (y/N) " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    echo "   Removing old installation..."
    rm -rf "${APPLICATIONS_DIR}/${APP_BUNDLE}"
fi

# Copy to Applications
echo "📦 Installing ${APP_NAME} to Applications..."
cp -R "${SOURCE_DIR}/${APP_BUNDLE}" "${APPLICATIONS_DIR}/${APP_BUNDLE}"

echo "✅ Installation complete!"
echo ""

# Launch
read -p "Launch ${APP_NAME} now? (Y/n) " -n 1 -r
echo ""
[[ ! $REPLY =~ ^[Nn]$ ]] && open "${APPLICATIONS_DIR}/${APP_BUNDLE}"

echo ""
echo "ALICE is now in your Applications folder."
echo "It will appear in your menu bar when launched."
echo ""
echo "First time setup:"
echo "  1. Grant Accessibility, Screen Recording, and Microphone permissions"
echo "  2. Hold ctrl+option to talk to ALICE"
echo ""
read -p "Press Enter to close this window..."