//
//  AIClient.swift
//  ALICE
//
//  Unified AI client supporting Claude and OpenAI through the gateway proxy.
//  SSE streaming for Claude, standard request/response for OpenAI.
//  Includes conversation history and TLS warmup.
//

import Foundation

struct AIResponse {
    let text: String
    let duration: TimeInterval
    let model: String
}

@MainActor
final class AIClient {
    private var session: URLSession
    private var gatewayURL: URL?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.urlCache = nil
        config.httpCookieStorage = nil
        self.session = URLSession(configuration: config)
        self.gatewayURL = AppConfiguration.gatewayURL()
        warmUpTLS()
    }

    /// Sends a vision request with a screenshot and user transcript.
    func sendVisionRequest(
        transcript: String,
        screenshotData: Data,
        displayLabel: String,
        model: AIModel,
        history: [(user: String, assistant: String)]
    ) async throws -> AIResponse {
        let startTime = Date()
        guard let gatewayURL = gatewayURL else {
            throw AIClientError.gatewayNotConfigured
        }

        let chatURL = gatewayURL.appendingPathComponent("chat")
        let mediaType = detectMediaType(data: screenshotData)
        let base64Image = screenshotData.base64EncodedString()

        let systemPrompt = """
        You are ALICE, an AI companion that lives on the user's macOS desktop. You can see their screen and help them with any task.

        When you reference a specific UI element on their screen, embed a pointing tag in this exact format:
        [POINT:x,y:label:displayNumber]

        Where x and y are the pixel coordinates of the element (origin top-left), label is a short name for the element, and displayNumber is the display index (1-based).

        Be concise and helpful. If the user asks a conceptual question with no UI element to point to, just answer normally.
        """

        // Build messages with conversation history
        var messages: [[String: Any]] = []

        for (userMsg, assistantMsg) in history.suffix(10) { // ponytail: last 10 turns
            messages.append(["role": "user", "content": userMsg])
            messages.append(["role": "assistant", "content": assistantMsg])
        }

        // Current message with image
        let currentMessage: [String: Any] = [
            "role": "user",
            "content": [
                [
                    "type": "text",
                    "text": "[\(displayLabel) screenshot]\n\nUser asked: \(transcript)"
                ],
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": mediaType,
                        "data": base64Image
                    ]
                ]
            ]
        ]
        messages.append(currentMessage)

        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 1024,
            "system": systemPrompt,
            "stream": model.rawValue.hasPrefix("claude"), // Stream Claude, not OpenAI
            "messages": messages
        ]

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if model.rawValue.hasPrefix("claude") {
            // SSE streaming
            let text = try await streamSSE(request: request)
            return AIResponse(text: text, duration: Date().timeIntervalSince(startTime), model: model.rawValue)
        } else {
            // Standard request
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                throw AIClientError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(body.prefix(200))")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let text = message["content"] as? String else {
                throw AIClientError.invalidResponse
            }

            return AIResponse(text: text, duration: Date().timeIntervalSince(startTime), model: model.rawValue)
        }
    }

    // MARK: - SSE Streaming

    private func streamSSE(request: URLRequest) async throws -> String {
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIClientError.apiError("Stream failed")
        }

        var fullText = ""
        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let jsonStr = String(line.dropFirst(6))
                if jsonStr == "[DONE]" { break }
                if let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Claude format: content_block_delta
                    if let delta = json["delta"] as? [String: Any],
                       let text = delta["text"] as? String {
                        fullText += text
                    }
                    // OpenAI format: choices[0].delta.content
                    if let choices = json["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let text = delta["content"] as? String {
                        fullText += text
                    }
                }
            }
        }

        return fullText
    }

    // MARK: - Helpers

    private func warmUpTLS() {
        guard let url = gatewayURL else { return }
        var warmup = URLRequest(url: url)
        warmup.httpMethod = "HEAD"
        warmup.timeoutInterval = 10
        session.dataTask(with: warmup) { _, _, _ in }.resume()
    }

    private func detectMediaType(data: Data) -> String {
        if data.count >= 4 {
            let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
            if Array(data.prefix(4)) == png { return "image/png" }
        }
        return "image/jpeg"
    }
}

enum AIClientError: Error {
    case gatewayNotConfigured
    case apiError(String)
    case invalidResponse
}
