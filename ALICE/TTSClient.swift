//
//  TTSClient.swift
//  ALICE
//
//  Text-to-speech via the gateway proxy (ElevenLabs backend).
//  Plays audio through system output. Waits for playback completion.
//

import AVFoundation
import Foundation

@MainActor
final class TTSClient: NSObject, AVAudioPlayerDelegate {
    private let session: URLSession
    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        super.init()
    }

    func speak(_ text: String) async throws {
        guard let gatewayURL = AppConfiguration.gatewayURL() else { return }
        let ttsURL = gatewayURL.appendingPathComponent("tts")

        var request = URLRequest(url: ttsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_flash_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            ALICEAnalytics.trackTTSError(error: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return
        }

        try Task.checkCancellation()

        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        self.audioPlayer = player
        player.play()

        // ponytail: wait for playback to finish before returning,
        // so voiceState stays .speaking until audio completes
        await withCheckedContinuation { continuation in
            self.playbackContinuation = continuation
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
            self.audioPlayer = nil
        }
    }

    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackContinuation?.resume()
        playbackContinuation = nil
    }
}