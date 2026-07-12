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

        // ponytail: use continuation safely — guard against double-resume
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()

            func resumeOnce(_ result: Result<String, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(with: result)
            }

            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    resumeOnce(.failure(error))
                    return
                }
                if let result = result, result.isFinal {
                    resumeOnce(.success(result.bestTranscription.formattedString))
                }
            }
        }
    }
}