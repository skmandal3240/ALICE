//
//  OpenAITranscriptionProvider.swift
//  ALICE
//
//  Upload-based transcription via OpenAI Whisper through the gateway proxy.
//

import Foundation

final class OpenAITranscriptionProvider: TranscriptionProvider {
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
        let audioData = try Data(contentsOf: audioFileURL)

        var request = URLRequest(url: gatewayURL.appendingPathComponent("transcribe"))
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // File part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return ""
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let text = json["text"] as? String else {
            return ""
        }

        return text
    }
}
