//
//  AppleSpeechTranscriptionProvider.swift
//  ALICE
//
//  Local fallback transcription using Apple's Speech framework.
//  No network calls, no API keys needed. Privacy-first.
//

import Foundation
import Speech

final class AppleSpeechTranscriptionProvider: TranscriptionProvider {
    func transcribe(audioFileURL: URL) async throws -> String {
        let recognizer = SFSpeechRecognizer(locale: Locale.current)
        guard let recognizer = recognizer, recognizer.isAvailable else {
            return ""
        }

        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
