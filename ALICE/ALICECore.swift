//
//  ALICECore.swift
//  Central state machine that orchestrates the full pipeline:
//  voice → screenshot → AI → TTS → orb animation → pointing
//

import AppKit
import Combine
import Foundation

@MainActor
final class ALICECore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var voiceState: VoiceState = .idle
    @Published private(set) var lastTranscript = ""
    @Published private(set) var lastResponse = ""
    @Published private(set) var conversationHistory: [(user: String, assistant: String)] = []
    @Published private(set) var selectedModel: AIModel = .claudeSonnet
    @Published private(set) var isOrbVisible = true
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var permissionsGranted = false
    @Published var pointingTarget: PointerTag?

    // MARK: - Subsystems

    let voicePipeline = VoicePipeline()
    let screenCapture = ScreenCaptureManager()
    let aiClient = AIClient()
    let ttsClient = TTSClient()
    let pointerDetector = PointerDetector()
    let permissionManager = PermissionManager()
    let shortcutMonitor = GlobalShortcutMonitor()

    private weak var orbManager: OrbWindowManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func bind(orbManager: OrbWindowManager) {
        self.orbManager = orbManager
    }

    func start() {
        permissionManager.checkAll()
        shortcutMonitor.start()
        voicePipeline.delegate = self
        screenCapture.delegate = self

        // Route shortcut events to voice pipeline
        shortcutMonitor.shortcutTransitionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transition in
                switch transition {
                case .pressed:
                    self?.startListening()
                case .released:
                    self?.stopListening()
                }
            }
            .store(in: &cancellables)

        // Poll permissions until granted
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            Task { @MainActor in
                self?.permissionManager.checkAll()
                if self?.permissionManager.allGranted == true {
                    self?.permissionsGranted = true
                    timer.invalidate()
                }
            }
        }
    }

    func stop() {
        shortcutMonitor.stop()
        voicePipeline.stop()
        ttsClient.stop()
    }

    // MARK: - Voice Pipeline

    func startListening() {
        guard permissionManager.allGranted else { return }
        ALICEAnalytics.trackVoiceStarted()
        voiceState = .listening
        Task {
            try? await voicePipeline.startCapture()
        }
    }

    func stopListening() {
        ALICEAnalytics.trackVoiceReleased()
        voiceState = .thinking
        Task {
            try? await voicePipeline.stopCapture()
        }
    }

    // MARK: - AI Pipeline

    func processTranscript(_ transcript: String) async {
        lastTranscript = transcript
        ALICEAnalytics.trackUserMessage(transcript: transcript)
        voiceState = .thinking

        // Capture screenshot of active display
        guard let screenshot = await screenCapture.captureActiveDisplay() else {
            voiceState = .idle
            return
        }

        // Send to AI with vision context
        do {
            let response = try await aiClient.sendVisionRequest(
                transcript: transcript,
                screenshotData: screenshot.data,
                displayLabel: screenshot.label,
                model: selectedModel,
                history: conversationHistory
            )

            lastResponse = response.text
            conversationHistory.append((user: transcript, assistant: response.text))
            ALICEAnalytics.trackAIResponse(response: response.text)

            // Speak the response
            voiceState = .speaking
            try await ttsClient.speak(response.text)

            // Check for pointing tags
            if let pointTag = PointerTagParser.parse(from: response.text) {
                ALICEAnalytics.trackElementPointed(label: pointTag.label)
                await orbManager?.animateToPoint(pointTag)
            }

            voiceState = .idle

        } catch {
            ALICEAnalytics.trackResponseError(error: error.localizedDescription)
            voiceState = .idle
        }
    }

    // MARK: - Model Selection

    func selectModel(_ model: AIModel) {
        selectedModel = model
    }

    // MARK: - Pointing

    func setPointingTarget(_ tag: PointerTag) {
        pointingTarget = tag
    }

    func clearPointingTarget() {
        pointingTarget = nil
    }
}

// MARK: - Voice Pipeline Delegate

extension ALICECore: VoicePipelineDelegate {
    nonisolated func voicePipeline(_ pipeline: VoicePipeline, didReceiveTranscript transcript: String) {
        Task { @MainActor in
            await self.processTranscript(transcript)
        }
    }

    nonisolated func voicePipeline(_ pipeline: VoicePipeline, didUpdateAudioLevel level: Float) {
        Task { @MainActor in
            self.audioLevel = level
        }
    }
}

// MARK: - Screen Capture Delegate

extension ALICECore: ScreenCaptureManagerDelegate {
    nonisolated func screenCaptureManager(_ manager: ScreenCaptureManager, didCaptureDisplay label: String) {
        // Used for logging/debug
    }
}

// MARK: - Enums

enum VoiceState: Equatable {
    case idle
    case listening
    case thinking
    case speaking
}

enum AIModel: String, CaseIterable {
    case claudeSonnet = "claude-sonnet-4-6"
    case claudeOpus = "claude-opus-4-6"
    case gpt52 = "gpt-5.2-2025-12-11"

    var displayName: String {
        switch self {
        case .claudeSonnet: return "Claude Sonnet"
        case .claudeOpus: return "Claude Opus"
        case .gpt52: return "GPT-5.2"
        }
    }
}
