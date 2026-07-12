//
//  PermissionManager.swift
//  ALICE
//
//  Manages macOS permission state: Accessibility, Screen Recording, Microphone.
//

import AppKit
import ApplicationServices
import AVFoundation
import Combine
import ScreenCaptureKit

@MainActor
final class PermissionManager: ObservableObject {

    @Published private(set) var hasAccessibility = false
    @Published private(set) var hasScreenRecording = false
    @Published private(set) var hasMicrophone = false

    private var hasPromptedAccessibility = false
    private var hasPromptedScreenRecording = false

    private let screenRecordingKey = "com.alice.hasScreenRecordingPermission"

    var allGranted: Bool {
        hasAccessibility && hasScreenRecording && hasMicrophone
    }

    var missingPermissions: [String] {
        var missing: [String] = []
        if !hasAccessibility { missing.append("Accessibility") }
        if !hasScreenRecording { missing.append("Screen Recording") }
        if !hasMicrophone { missing.append("Microphone") }
        return missing
    }

    func checkAll() {
        hasAccessibility = AXIsProcessTrusted()

        let screenGranted = CGPreflightScreenCaptureAccess()
        if screenGranted {
            UserDefaults.standard.set(true, forKey: screenRecordingKey)
        }
        // ponytail: CGPreflight can false-negative after restart; trust cache
        hasScreenRecording = screenGranted || UserDefaults.standard.bool(forKey: screenRecordingKey)

        // ponytail: AVAudioApplication.recordPermission is the correct API (macOS 14+)
        hasMicrophone = AVAudioApplication.shared.recordPermission == .granted
    }

    func requestAccessibility() {
        guard !hasAccessibility else { return }
        if !hasPromptedAccessibility {
            hasPromptedAccessibility = true
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        } else {
            openSettings(pane: "Privacy_Accessibility")
        }
    }

    func requestScreenRecording() {
        guard !hasScreenRecording else { return }
        if !hasPromptedScreenRecording {
            hasPromptedScreenRecording = true
            _ = CGRequestScreenCaptureAccess()
        } else {
            openSettings(pane: "Privacy_ScreenCapture")
        }
    }

    func requestMicrophone() {
        // ponytail: AVAudioApplication.requestRecordPermission triggers the system prompt
        // on first call. The voice pipeline triggers this naturally on first capture.
        // No manual request needed here — just open settings if already denied.
        if !hasMicrophone {
            openSettings(pane: "Privacy_Microphone")
        }
    }

    func revealAppInFinder() {
        let url = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openSettings(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}