//
//  ALICEAnalytics.swift
//  ALICE
//
//  Centralized analytics wrapper. PostHog optional, no-op if unconfigured.
//

import Foundation
import PostHog

enum ALICEAnalytics {

    private static var isConfigured = false

    static func configure() {
        guard let key = AppConfiguration.stringValue(forKey: "ALICE_ANALYTICS_KEY"),
              !key.isEmpty,
              let host = AppConfiguration.stringValue(forKey: "ALICE_ANALYTICS_HOST"),
              !host.isEmpty else {
            return
        }
        let config = PostHogConfig(apiKey: key, host: host)
        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    // MARK: - Lifecycle

    static func trackAppOpened() {
        guard isConfigured else { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        PostHogSDK.shared.capture("alice_app_opened", properties: ["version": version])
    }

    // MARK: - Voice

    static func trackVoiceStarted() {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("alice_voice_started")
    }

    static func trackVoiceReleased() {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("alice_voice_released")
    }

    static func trackUserMessage(transcript: String) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("alice_user_message", properties: ["character_count": transcript.count])
    }

    static func trackAIResponse(response: String) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("alice_ai_response", properties: ["character_count": response.count])
    }

    static func trackElementPointed(label: String?) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("alice_element_pointed", properties: ["label": label ?? "unknown"])
    }

    // MARK: - Errors

    static func trackResponseError(error: String) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("alice_response_error", properties: ["error": error])
    }

    static func trackTTSError(error: String) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("alice_tts_error", properties: ["error": error])
    }
}