//
//  AssemblyAITranscriptionProvider.swift
//  ALICE
//
//  Upload-based transcription via AssemblyAI through the gateway proxy.
//  For streaming transcription, a websocket-based provider would replace this.
//  ponytail: upload-based is simpler and sufficient for push-to-talk bursts.
//

import Foundation

final class AssemblyAITranscriptionProvider: TranscriptionProvider {
    private let gatewayURL: URL
    private let session: URLSession

    init(gatewayURL: URL) {
        self.gatewayURL = gatewayURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        // Step 1: Request an upload URL from our gateway
        var tokenRequest = URLRequest(url: gatewayURL.appendingPathComponent("transcribe-token"))
        tokenRequest.httpMethod = "POST"
        let (tokenData, tokenResponse) = try await session.data(for: tokenRequest)

        guard let httpResponse = tokenResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return ""
        }

        guard let tokenJSON = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let uploadURLString = tokenJSON["upload_url"] as? String,
              let uploadURL = URL(string: uploadURLString) else {
            return ""
        }

        // Step 2: Upload the audio file
        let audioData = try Data(contentsOf: audioFileURL)
        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = audioData
        let (_, uploadResponse) = try await session.data(for: uploadRequest)

        guard let uploadHTTPResponse = uploadResponse as? HTTPURLResponse,
              (200...299).contains(uploadHTTPResponse.statusCode) else {
            return ""
        }

        // Step 3: Submit for transcription
        var transcribeRequest = URLRequest(url: gatewayURL.appendingPathComponent("transcribe"))
        transcribeRequest.httpMethod = "POST"
        transcribeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["audio_url": uploadURLString]
        transcribeRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (transcribeData, _) = try await session.data(for: transcribeRequest)

        guard let transcribeJSON = try? JSONSerialization.jsonObject(with: transcribeData) as? [String: Any],
              let transcriptID = transcribeJSON["id"] as? String else {
            return ""
        }

        // Step 4: Poll for completion
        return try await pollForTranscript(id: transcriptID)
    }

    private func pollForTranscript(id: String) async throws -> String {
        // ponytail: appendingPathComponent doesn't handle path components with slashes
        // Use appending(path:) which is available on macOS 14+
        let pollURL = gatewayURL.appending(path: "transcribe/\(id)")
        for _ in 0..<60 { // ponytail: max 60 polls × 2s = 2 min timeout
            try await Task.sleep(nanoseconds: 2_000_000_000)
            var request = URLRequest(url: pollURL)
            request.httpMethod = "GET"
            let (data, _) = try await session.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else { continue }
            if status == "completed" {
                return json["text"] as? String ?? ""
            }
            if status == "error" { return "" }
        }
        return ""
    }
}
