# ALICE

**ALICE — an AI companion that lives on your macOS desktop.**

ALICE is a menu-bar-only macOS app that sees your screen, hears your voice, and helps you with any task. It floats as an orb next to your cursor, responds with voice, and can point at UI elements on your screen to guide you.

## What makes ALICE different

| Feature | ALICE | Other AI assistants |
|---------|-------|-------------------|
| Lives next to your cursor | ✅ Orb follows cursor | ❌ Separate window |
| Voice-first interaction | ✅ Push-to-talk | ❌ Text-only or voice as afterthought |
| Points at UI elements | ✅ Flies to and highlights elements | ❌ Text descriptions only |
| Multi-monitor support | ✅ Captures all displays | ❌ Single display |
| Pluggable transcription | ✅ AssemblyAI, OpenAI, Apple Speech | ❌ Single provider |
| Multi-model AI | ✅ Claude Sonnet/Opus, GPT-5.2 | ❌ Single model |
| Streaming responses | ✅ SSE streaming for Claude | ❌ Full response wait |
| Privacy-first | ✅ API keys on Cloudflare Worker, local speech fallback | ❌ Keys in app or no fallback |
| No API keys in the app | ✅ Gateway proxy | ❌ Keys shipped in binary |

## Architecture

- **App Type**: Menu-bar-only (`LSUIElement=true`), no dock icon
- **Framework**: SwiftUI (macOS native) with AppKit bridging
- **Pattern**: MVVM with `@Published` state management
- **AI**: Claude (Sonnet/Opus) via SSE streaming, OpenAI GPT-5.2 via standard request
- **Speech-to-Text**: Pluggable — AssemblyAI (streaming), OpenAI Whisper (upload), Apple Speech (local fallback)
- **Text-to-Speech**: ElevenLabs via gateway proxy
- **Screen Capture**: ScreenCaptureKit (macOS 14.2+), multi-monitor
- **Voice Input**: Push-to-talk via `AVAudioEngine` + pluggable transcription
- **Element Pointing**: Claude Computer Use API for pixel-accurate element detection
- **Concurrency**: `@MainActor` isolation, async/await throughout
- **Analytics**: PostHog (optional, disabled by default)

### Gateway Proxy (Cloudflare Worker)

The app never touches API keys directly. All requests route through a Cloudflare Worker.

| Route | Upstream | Purpose |
|-------|----------|---------|
| `POST /chat` | Anthropic / OpenAI | Vision chat (streaming for Claude) |
| `POST /tts` | ElevenLabs | Text-to-speech audio |
| `POST /transcribe` | OpenAI Whisper | Audio transcription |
| `POST /transcribe-token` | AssemblyAI | Upload URL for audio |
| `GET /transcribe/:id` | AssemblyAI | Poll transcript status |
| `POST /computer-use` | Anthropic Computer Use | Element location detection |

## Repository structure

```
ALICE/
├── ALICE/                          # Swift source
│   ├── ALICEApp.swift              # App entry point
│   ├── ALICECore.swift             # Central state machine
│   ├── AppConfiguration.swift      # Bundle config reader
│   ├── AIClient.swift              # Unified AI client (Claude + OpenAI)
│   ├── TTSClient.swift             # Text-to-speech client
│   ├── VoicePipeline.swift         # Push-to-talk + provider factory
│   ├── AppleSpeechTranscriptionProvider.swift
│   ├── AssemblyAITranscriptionProvider.swift
│   ├── OpenAITranscriptionProvider.swift
│   ├── ScreenCaptureManager.swift  # Multi-monitor screenshots
│   ├── GlobalShortcutMonitor.swift # CGEvent tap push-to-talk
│   ├── PermissionManager.swift     # Accessibility/Screen/Mic permissions
│   ├── PointerDetector.swift       # Computer Use element detection
│   ├── OrbWindowManager.swift      # Transparent overlay + orb animation
│   ├── OrbPanelView.swift          # Menu bar dropdown panel
│   ├── MenuBarController.swift     # NSStatusItem lifecycle
│   ├── DesignSystem.swift          # Colors, typography, spacing tokens
│   ├── ALICEAnalytics.swift        # PostHog wrapper
│   ├── Info.plist
│   └── ALICE.entitlements
├── ALICETests/
│   └── ALICETests.swift            # Unit tests
├── gateway/                        # Cloudflare Worker
│   ├── src/index.ts
│   ├── wrangler.toml
│   ├── package.json
│   └── tsconfig.json
├── project.yml                     # XcodeGen project definition
├── scripts/
│   └── release.sh                  # Release pipeline (archive, sign, DMG, notarize)
└── README.md
```

## Getting started

### Prerequisites

- macOS 14.2+ (for ScreenCaptureKit)
- Xcode 16+ (or XcodeGen + Xcode)
- Node.js 18+ (for the Cloudflare Worker)
- A Cloudflare account (free tier works)

### 1. Deploy the gateway

```bash
cd gateway
npm install

# Set your API keys as secrets
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
npx wrangler secret put ASSEMBLYAI_API_KEY

# Deploy
npx wrangler deploy
```

Note the deployed URL (e.g., `https://alice-gateway.your-subdomain.workers.dev`).

### 2. Build the app

**Option A — XcodeGen:**

```bash
# Install XcodeGen
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open ALICE.xcodeproj
```

**Option B — Manual Xcode:**

Create a new macOS app project in Xcode, add all Swift files from `ALICE/`, add the PostHog and Sparkle SPM packages, and set the Info.plist and entitlements.

### 3. Configure the app

In Xcode, edit the Info.plist:

- `ALICE_GATEWAY_URL` → your deployed Worker URL
- `VOICE_TRANSCRIPTION_PROVIDER` → `apple` (local), `openai`, or `assemblyai`
- `ALICE_ANALYTICS_KEY` / `ALICE_ANALYTICS_HOST` → your PostHog keys (optional)

### 4. Run

Build and run in Xcode. ALICE appears in your menu bar. Grant the three permissions (Accessibility, Screen Recording, Microphone). Press and hold **ctrl + option** to talk.

## Usage

1. **ALICE appears in your menu bar** as a small circle icon.
2. **Click the menu bar icon** to open the settings panel — choose your AI model.
3. **Press and hold ctrl + option** to start talking. The orb glows red while listening.
4. **Release** to send. ALICE captures your screen, sends it with your transcript to the AI, and responds with text + voice.
5. **The orb follows your cursor** and can fly to point at UI elements the AI references.

## Configuration

### Transcription providers

| Provider | Info.plist value | Network | Quality | Privacy |
|----------|-----------------|---------|---------|---------|
| Apple Speech | `apple` | None | Good | Fully local |
| OpenAI Whisper | `openai` | Required | Excellent | Audio sent to OpenAI |
| AssemblyAI | `assemblyai` | Required | Excellent | Audio sent to AssemblyAI |

### AI models

| Model | Info.plist value | Streaming | Vision |
|-------|-----------------|-----------|--------|
| Claude Sonnet | `claude-sonnet-4-6` | ✅ SSE | ✅ |
| Claude Opus | `claude-opus-4-6` | ✅ SSE | ✅ |
| GPT-5.2 | `gpt-5.2-2025-12-11` | ❌ | ✅ |

## License

MIT — see [LICENSE](LICENSE).

## Contributing

ALICE is an open project. PRs welcome.
