# ALICE Scripts

## build-installer.sh

Builds ALICE and creates a macOS DMG installer.

```bash
# Unsigned DMG (for local use / testing)
./scripts/build-installer.sh

# Clean build + DMG
./scripts/build-installer.sh --clean

# Signed + notarized DMG (for distribution)
./scripts/build-installer.sh --signed
```

**Prerequisites:**
- macOS 14.2+ (Sonoma)
- Xcode 16+
- `brew install xcodegen create-dmg`
- For signing: Apple Developer ID certificate + `xcrun notarytool store-credentials "AC_PASSWORD"`

## install.command

Double-clickable installer script. Users double-click this file after mounting the DMG to install ALICE to `/Applications`.

## release.sh

Full release pipeline: archive, sign, notarize, DMG, GitHub Release.