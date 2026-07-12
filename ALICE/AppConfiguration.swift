//
//  AppConfiguration.swift
//  ALICE
//
//  Reads runtime configuration from the app bundle's Info.plist.
//

import Foundation

enum AppConfiguration {
    static func gatewayURL() -> URL? {
        guard let raw = stringValue(forKey: "ALICE_GATEWAY_URL") else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    static func stringValue(forKey key: String) -> String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        // ponytail: fallback to reading Info.plist as a resource file
        // needed when Info.plist is processed by Xcode build
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let value = dict[key] as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}