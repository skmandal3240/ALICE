//
//  AppConfiguration.swift
//  ALICE
//
//  Reads runtime configuration from the app bundle's Info.plist.
//  The gateway proxy URL is injected at build time via Info.plist.
//

import Foundation

enum AppConfiguration {
    static func gatewayURL() -> URL? {
        guard let raw = stringValue(forKey: "ALICE_GATEWAY_URL"),
              let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines) as String?,
              !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed)
    }

    static func stringValue(forKey key: String) -> String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = value.trimmingCharacters(in: .whitesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let value = dict[key] as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
