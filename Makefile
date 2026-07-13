# ALICE — Makefile
# Common build commands for development

.PHONY: all build clean dmg signed-dmg install deps test gateway deploy-gateway

# Default: build the project
all: build

# Generate Xcode project and build
build:
	xcodegen generate
	xcodebuild build -scheme ALICE -configuration Release \
		-derivedDataPath build/DerivedData \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Build unsigned DMG installer
dmg:
	./scripts/build-installer.sh

# Build signed + notarized DMG installer
signed-dmg:
	./scripts/build-installer.sh --signed

# Clean build artifacts
clean:
	rm -rf build/
	rm -rf DerivedData/
	xcodebuild clean -scheme ALICE 2>/dev/null || true

# Run tests
test:
	xcodegen generate
	xcodebuild test -scheme ALICE -destination 'platform=macOS'

# Install dependencies (gateway)
deps:
	cd gateway && npm install

# Run gateway locally
gateway:
	cd gateway && npx wrangler dev

# Deploy gateway to Cloudflare
deploy-gateway:
	cd gateway && npx wrangler deploy