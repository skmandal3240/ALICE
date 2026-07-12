//
//  ScreenCaptureManager.swift
//  ALICE
//
//  Multi-monitor screenshot capture via ScreenCaptureKit (macOS 14.2+).
//  Captures the display that contains the current mouse location.
//

import AppKit
import ScreenCaptureKit
import CoreGraphics

protocol ScreenCaptureManagerDelegate: AnyObject {
    func screenCaptureManager(_ manager: ScreenCaptureManager, didCaptureDisplay label: String)
}

struct CapturedDisplay {
    let data: Data
    let label: String
    let displayID: CGDirectDisplayID
    let widthInPoints: Int
    let heightInPoints: Int
}

@MainActor
final class ScreenCaptureManager {
    weak var delegate: ScreenCaptureManagerDelegate?

    func captureActiveDisplay() async -> CapturedDisplay? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens

        guard let targetScreen = screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            return nil
        }

        let displayID = targetScreen.displayID
        let width = Int(targetScreen.frame.width)
        let height = Int(targetScreen.frame.height)
        let labelIndex = screens.firstIndex(of: targetScreen).map { $0 + 1 } ?? 1

        guard let data = await captureDisplay(displayID: displayID, width: width, height: height) else {
            return nil
        }

        let label = "Display \(labelIndex)"
        delegate?.screenCaptureManager(self, didCaptureDisplay: label)
        return CapturedDisplay(data: data, label: label, displayID: displayID, widthInPoints: width, heightInPoints: height)
    }

    func captureAllDisplays() async -> [CapturedDisplay] {
        var results: [CapturedDisplay] = []
        for (index, screen) in NSScreen.screens.enumerated() {
            let displayID = screen.displayID
            let width = Int(screen.frame.width)
            let height = Int(screen.frame.height)
            if let data = await captureDisplay(displayID: displayID, width: width, height: height) {
                results.append(CapturedDisplay(data: data, label: "Display \(index + 1)", displayID: displayID, widthInPoints: width, heightInPoints: height))
            }
        }
        return results
    }

    private func captureDisplay(displayID: CGDirectDisplayID, width: Int, height: Int) async -> Data? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return nil }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = width * 2  // ponytail: 2x for Retina
            config.height = height * 2
            config.scalesDown = true

            let image = try await SCScreenshotGenerator.captureImage(contentFilter: filter, configuration: config)
            let bitmapRep = NSBitmapImageRep(cgImage: image)
            guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                return nil
            }
            return jpegData
        } catch {
            return nil
        }
    }
}

// MARK: - NSScreen Extension

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}