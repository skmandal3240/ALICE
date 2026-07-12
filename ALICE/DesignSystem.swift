//
//  DesignSystem.swift
//  ALICE
//
//  Centralized colors, typography, and spacing tokens.
//

import SwiftUI

enum DS {
    // MARK: - Colors

    static let orbIdle = Color(red: 0.45, green: 0.55, blue: 1.0)
    static let orbListening = Color(red: 1.0, green: 0.4, blue: 0.5)
    static let orbThinking = Color(red: 0.3, green: 0.8, blue: 1.0)
    static let orbSpeaking = Color(red: 0.5, green: 1.0, blue: 0.6)

    static let panelBg = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let panelBorder = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.5)

    // MARK: - Typography

    static let captionFont = Font.system(size: 11, weight: .medium)
    static let bodyFont = Font.system(size: 13, weight: .regular)
    static let labelFont = Font.system(size: 12, weight: .semibold)
    static let titleFont = Font.system(size: 15, weight: .bold)

    // MARK: - Spacing

    static let padXS: CGFloat = 4
    static let padS: CGFloat = 8
    static let padM: CGFloat = 12
    static let padL: CGFloat = 16
    static let padXL: CGFloat = 24

    // MARK: - Corner Radius

    static let radiusS: CGFloat = 6
    static let radiusM: CGFloat = 10
    static let radiusL: CGFloat = 16
    static let radiusXL: CGFloat = 24

    // MARK: - Orb

    static let orbSize: CGFloat = 48
    static let orbGlowRadius: CGFloat = 20
}
