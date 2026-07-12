//
//  VoicePipeline.swift
//  ALICE
//
//  Pluggable push-to-talk voice capture and transcription.
//  Supports three backends: AssemblyAI (streaming), OpenAI (upload), Apple Speech (local).
//  Provider is selected via Info.plist key VOICE_TRANSCRIPTION_PROVIDER.
//

import AppKit
import AVFoundation
import Combine
import Foundation
import Speech

protocol VoicePipelineDelegate: AnyObject {
    func voicePipeline(_ pipeline: VoicePipeline, didReceiveTranscript transcript: String)
    func voicePipeline(_ pipeline: VoicePipeline, didUpdateAudioLevel level: Float)
}

@MainActor
final class VoicePipeline {
    weak var delegate: VoicePipelineDelegate?

    private let audioEngine = AVAudioEngine()
    private var recordingFile: AVAudioFile?
    private var tempFileURL: URL?
    private var provider: TranscriptionProvider?

    // Audio level monitoring
    private var levelTimer: Timer?
    private var lastLevel: Float = 0

    init() {
        provider = TranscriptionProviderFactory.resolve()
    }

    func startCapture() async throws {
        guard provider != nil else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("alice-\(UUID().uuidString).wav")
        recordingFile = try AVAudioFile(
            forWriting: tempFileURL!,
            settings: recordingFormat.settings
        )

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // ponytail: audio tap runs on a background thread; write to file
            // and compute level without touching main-actor state directly
            guard let self else { return }
            try? self.recordingFile?.write(from: buffer)
            self.computeAudioLevel(buffer: buffer)
        }

        try audioEngine.start()
        startLevelMonitor()
    }

    func stopCapture() async throws {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        levelTimer?.invalidate()
        recordingFile = nil

        guard let fileURL = tempFileURL, let provider = provider else {
            return
        }

        let transcript = try await provider.transcribe(audioFileURL: fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        tempFileURL = nil

        if !transcript.isEmpty {
            delegate?.voicePipeline(self, didReceiveTranscript: transcript)
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        levelTimer?.invalidate()
    }

    // MARK: - Audio Level

    private func startLevelMonitor() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.delegate?.voicePipeline(self, didUpdateAudioLevel: self.lastLevel)
            }
        }
    }

    // ponytail: nonisolated — called from audio tap callback on background thread.
    // Only touches lastLevel via a Task to hop back to MainActor.
    nonisolated private func computeAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        let level = min(1.0, rms * 5.0)

        Task { @MainActor in
            self.lastLevel = level
        }
    }
}

// MARK: - Transcription Provider Protocol

protocol TranscriptionProvider {
    func transcribe(audioFileURL: URL) async throws -> String
}

// MARK: - Provider Factory

enum TranscriptionProviderFactory {
    static func resolve() -> TranscriptionProvider? {
        let providerType = AppConfiguration.stringValue(forKey: "VOICE_TRANSCRIPTION_PROVIDER") ?? "apple"

        switch providerType.lowercased() {
        case "assemblyai":
            guard let gatewayURL = AppConfiguration.gatewayURL() else { return nil }
            return AssemblyAITranscriptionProvider(gatewayURL: gatewayURL)

        case "openai":
            guard let gatewayURL = AppConfiguration.gatewayURL() else { return nil }
            return OpenAITranscriptionProvider(gatewayURL: gatewayURL)

        case "apple":
            return AppleSpeechTranscriptionProvider()

        default:
            return AppleSpeechTranscriptionProvider()
        }
    }
}