# ALICE — Agent Instructions

## Overview

macOS menu bar AI companion. Lives as a floating orb next to the cursor. Push-to-talk voice input, screen capture, Claude/OpenAI vision, ElevenLabs TTS, and Computer Use element pointing.

## Architecture

- **App Type**: Menu-bar-only (`LSUIElement=true`)
- **Framework**: SwiftUI + AppKit bridging
- **AI**: Claude (SSE streaming) and OpenAI (standard) via Cloudflare Worker gateway
- **STT**: Pluggable — AssemblyAI, OpenAI Whisper, Apple Speech (local fallback)
- **TTS**: ElevenLabs via gateway proxy
- **Screen**: ScreenCaptureKit, multi-monitor, captures active display
- **Shortcut**: CGEvent tap (listen-only) for ctrl+option push-to-talk
- **Pointing**: [POINT:x,y:label:display] tags parsed from AI response + Computer Use API for detection
- **Concurrency**: @MainActor, async/await

## Key Files

| File | Purpose |
|------|---------|
| `ALICEApp.swift` | App entry point, creates core + orb manager |
| `ALICECore.swift` | Central state machine: voice → screenshot → AI → TTS → pointing |
| `AIClient.swift` | Unified Claude/OpenAI client with SSE streaming |
| `VoicePipeline.swift` | Push-to-talk + transcription provider factory |
| `ScreenCaptureManager.swift` | Multi-monitor ScreenCaptureKit capture |
| `GlobalShortcutMonitor.swift` | CGEvent tap for system-wide push-to-talk |
| `PermissionManager.swift` | Accessibility, Screen Recording, Microphone |
| `PointerDetector.swift` | Computer Use element detection + PointerTagParser |
| `OrbWindowManager.swift` | Transparent overlay hosting the orb + animations |
| `OrbPanelView.swift` | Menu bar dropdown: status, model picker, permissions |
| `MenuBarController.swift` | NSStatusItem lifecycle |
| `gateway/src/index.ts` | Cloudflare Worker proxy (all API keys as secrets) |

## Gateway Routes

| Route | Upstream |
|-------|----------|
| `POST /chat` | Anthropic / OpenAI |
| `POST /tts` | ElevenLabs |
| `POST /transcribe` | OpenAI Whisper |
| `POST /transcribe-token` | AssemblyAI |
| `GET /transcribe/:id` | AssemblyAI poll |
| `POST /computer-use` | Anthropic Computer Use |
