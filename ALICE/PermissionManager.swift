//
//  PermissionManager.swift
//  ALICE
//
//  Manages macOS permission state: Accessibility, Screen Recording, Microphone.
//  Provides a clean API to check, request, and monitor all three.
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
        hasScreenRecording = CGPreflightScreenCaptureAccess()
        if hasScreenRecording {
            UserDefaults.standard.set(true, forKey: screenRecordingKey)
        }
        // ponytail: if CGPreflight says no but we previously confirmed, trust the cache
        // CGPreflight can return false-negative after restart before first capture
        if !hasScreenRecording && UserDefaults.standard.bool(forKey: screenRecordingKey) {
            hasScreenRecording = true
        }

        let micStatus = AVAudioApplication.requestRecordPermissionPermission()
        hasMicrophone = (micStatus == .granted)
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
        // ponytail: AVAudioApplication handles the prompt on first use
        // The voice pipeline will trigger this naturally
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
