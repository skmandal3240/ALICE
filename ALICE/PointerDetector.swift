//
//  PointerDetector.swift
//  ALICE
//
//  Detects UI element locations in screenshots using Claude Computer Use API.
//  Maps coordinates from the AI resolution back to actual display points.
//

import AppKit
import Foundation

struct PointerTarget: Equatable {
    let point: CGPoint
    let label: String
    let displayIndex: Int
}

struct PointerTag: Equatable {
    let x: CGFloat
    let y: CGFloat
    let label: String
    let displayIndex: Int
}

enum PointerTagParser {
    /// Parses [POINT:x,y:label:displayNumber] tags from AI response text.
    static func parse(from text: String) -> PointerTag? {
        // ponytail: regex parse the first POINT tag
        let pattern = #"\[POINT:(\d+(?:\.\d+)?),(\d+(?:\.\d+)?):([^:]+):(\d+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, range: range) {
            let xStr = String(text[Range(match.range(at: 1), in: text)!])
            let yStr = String(text[Range(match.range(at: 2), in: text)!])
            let label = String(text[Range(match.range(at: 3), in: text)!])
            let displayStr = String(text[Range(match.range(at: 4), in: text)!])
            return PointerTag(
                x: CGFloat(Double(xStr) ?? 0),
                y: CGFloat(Double(yStr) ?? 0),
                label: label,
                displayIndex: Int(displayStr) ?? 1
            )
        }
        return nil
    }
}

class PointerDetector {
    private let session: URLSession

    // Anthropic-recommended Computer Use resolutions, matched to display aspect ratio
    private static let resolutions: [(w: Int, h: Int, ratio: Double)] = [
        (1024, 768, 1024.0 / 768.0),   // 4:3
        (1280, 800, 1280.0 / 800.0),   // 16:10 (most Macs)
        (1366, 768, 1366.0 / 768.0),   // ~16:9
    ]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.urlCache = nil
        config.httpCookieStorage = nil
        self.session = URLSession(configuration: config)
    }

    func detectElement(
        screenshotData: Data,
        userQuestion: String,
        displayWidth: Int,
        displayHeight: Int
    ) async -> PointerTarget? {
        // Pick closest aspect ratio resolution
        let displayRatio = Double(displayWidth) / Double(max(1, displayHeight))
        let best = Self.resolutions.min(by: { abs($0.ratio - displayRatio) < abs($1.ratio - displayRatio) }) ?? (1280, 800, 1.6)

        guard let resized = resize(data: screenshotData, to: best.w, height: best.h) else { return nil }

        // ponytail: Computer Use API call through gateway
        guard let gatewayURL = AppConfiguration.gatewayURL() else { return nil }
        var request = URLRequest(url: gatewayURL.appendingPathComponent("computer-use"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let mediaType = detectMediaType(data: resized)
        let base64 = resized.base64EncodedString()

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 256,
            "display_width": best.w,
            "display_height": best.h,
            "screenshot": [
                "media_type": mediaType,
                "data": base64
            ],
            "question": userQuestion
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (responseData, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return nil }

            guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let coordinate = json["coordinate"] as? [Double], coordinate.count == 2 else { return nil }

            let rawX = CGFloat(coordinate[0])
            let rawY = CGFloat(coordinate[1])

            // Clamp
            let clampedX = max(0, min(rawX, CGFloat(best.w)))
            let clampedY = max(0, min(rawY, CGFloat(best.h)))

            // Scale to actual display points
            let scaledX = (clampedX / CGFloat(best.w)) * CGFloat(displayWidth)
            let scaledYTop = (clampedY / CGFloat(best.h)) * CGFloat(displayHeight)
            let scaledYBottom = CGFloat(displayHeight) - scaledYTop // top-left → bottom-left origin

            let label = json["label"] as? String ?? "element"
            let displayIndex = json["display"] as? Int ?? 1

            return PointerTarget(
                point: CGPoint(x: scaledX, y: scaledYBottom),
                label: label,
                displayIndex: displayIndex
            )
        } catch {
            return nil
        }
    }

    // MARK: - Image Resize

    private func resize(data: Data, to width: Int, height: Int) -> Data? {
        guard let image = NSImage(data: data) else { return nil }

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        bitmapRep.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current = ctx
        ctx?.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }

    private func detectMediaType(data: Data) -> String {
        if data.count >= 4 {
            let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
            if Array(data.prefix(4)) == png { return "image/png" }
        }
        return "image/jpeg"
    }
}
