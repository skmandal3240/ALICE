//
//  ALICEAnalytics.swift
//  ALICE
//
//  Centralized analytics wrapper. Currently uses PostHog.
//  All event names defined here for consistency and auditability.
//

import Foundation
import PostHog

enum ALICEAnalytics {

    static func configure() {
        // ponytail: PostHog config key injected via Info.plist at build time
        // For local dev, analytics is a no-op if no key is set
        guard let key = AppConfiguration.stringValue(forKey: "ALICE_ANALYTICS_KEY") else { return }
        guard let host = AppConfiguration.stringValue(forKey: "ALICE_ANALYTICS_HOST") else { return }

        let config = PostHogConfig(apiKey: key, host: host)
        PostHogSDK.shared.setup(config)
    }

    // MARK: - Lifecycle

    static func trackAppOpened() {
        guard PostHogSDK.shared.isConfigured else { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        PostHogSDK.shared.capture("alice_app_opened", properties: ["version": version])
    }

    // MARK: - Voice

    static func trackVoiceStarted() {
        guard PostHogSDK.shared.isConfigured else { return }
        PostHogSDK.shared.capture("alice_voice_started")
    }

    static func trackVoiceReleased() {
        guard PostHogSDK.shared.isConfigured else { return }
        PostHogSDK.shared.capture("alice_voice_released")
    }

    static func trackUserMessage(transcript: String) {
        guard PostHogSDK.shared.isConfigured else { return }
        PostHogSDK.shared.capture("alice_user_message", properties: [
            "character_count": transcript.count
        ])
    }

    static func trackAIResponse(response: String) {
        guard PostHogSDK.shared.isConfigured else { return }
        PostHogSDK.shared.capture("alice_ai_response", properties: [
            "character_count": response.count
        ])
    }

    static func trackElementPointed(label: String?) {
        guard PostHogSDK.shared.isConfigured else { return }
        PostHogSDK.shared.capture("alice_element_pointed", properties: [
            "label": label ?? "unknown"
        ])
    }

    // MARK: - Errors

    static func trackResponseError(error: String) {
        guard PostHogSDK.shared.isConfigured else { return }
        PostHogSDK.shared.capture("alice_response_error", properties: ["error": error])
    }

    static func trackTTSError(error: String) {
        guard PostHogSDK.shared.isConfigured else { return }
        PostHogSDK.shared.capture("alice_tts_error", properties: ["error": error])
    }
}
