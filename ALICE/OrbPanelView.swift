//
//  OrbPanelView.swift
//  ALICE
//
//  SwiftUI content for the menu bar dropdown panel.
//  Shows status, permissions, model picker, and settings.
//

import SwiftUI

struct OrbPanelView: View {
    @ObservedObject var core: ALICECore
    @ObservedObject var permissions = PermissionManager()
    var onQuit: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                OrbShape(state: core.voiceState, audioLevel: 0)
                    .frame(width: 24, height: 24)

                Text("ALICE")
                    .font(DS.titleFont)
                    .foregroundColor(DS.textPrimary)

                Spacer()

                Text(statusText)
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
            }
            .padding(DS.padM)

            Divider()
                .background(DS.panelBorder)

            // Permissions section
            if !permissions.allGranted {
                VStack(alignment: .leading, spacing: DS.padS) {
                    Text("Permissions needed")
                        .font(DS.labelFont)
                        .foregroundColor(DS.textPrimary)

                    ForEach(permissions.missingPermissions, id: \.self) { perm in
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            Text(perm)
                                .font(DS.bodyFont)
                                .foregroundColor(DS.textSecondary)
                            Spacer()
                            Button("Grant") {
                                switch perm {
                                case "Accessibility": permissions.requestAccessibility()
                                case "Screen Recording": permissions.requestScreenRecording()
                                case "Microphone": permissions.requestMicrophone()
                                default: break
                                }
                            }
                            .font(DS.captionFont)
                            .buttonStyle(.borderless)
                            .foregroundColor(DS.orbIdle)
                        }
                        .padding(.horizontal, DS.padS)
                    }
                }
                .padding(DS.padM)
                .background(DS.panelBg)
            } else {
                // Model picker
                VStack(alignment: .leading, spacing: DS.padS) {
                    Text("AI Model")
                        .font(DS.labelFont)
                        .foregroundColor(DS.textPrimary)

                    HStack {
                        ForEach(AIModel.allCases, id: \.self) { model in
                            Button(action: { core.selectModel(model) }) {
                                Text(model.displayName)
                                    .font(DS.captionFont)
                                    .padding(.horizontal, DS.padS)
                                    .padding(.vertical, DS.padXS)
                                    .background(
                                        RoundedRectangle(cornerRadius: DS.radiusS)
                                            .fill(core.selectedModel == model ? DS.orbIdle.opacity(0.3) : Color.clear)
                                    )
                                    .foregroundColor(core.selectedModel == model ? DS.textPrimary : DS.textSecondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(DS.padM)
                .background(DS.panelBg)
            }

            Divider()
                .background(DS.panelBorder)

            // Instructions
            VStack(alignment: .leading, spacing: DS.padXS) {
                Text("Push to talk")
                    .font(DS.labelFont)
                    .foregroundColor(DS.textPrimary)

                HStack(spacing: DS.padXS) {
                    KeyCap(text: "ctrl")
                    Text("+")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    KeyCap(text: "option")
                    Text("hold to talk")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                }
            }
            .padding(DS.padM)
            .background(DS.panelBg)

            Spacer()

            // Footer
            HStack {
                Text("ALICE v1.0")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                Spacer()
                Button("Quit") { onQuit() }
                    .font(DS.captionFont)
                    .buttonStyle(.borderless)
                    .foregroundColor(DS.textSecondary)
            }
            .padding(DS.padM)
        }
        .frame(width: 280, height: permissions.allGranted ? 240 : 360)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusL)
                .fill(DS.panelBg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusL)
                        .stroke(DS.panelBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 12)
        )
    }

    private var statusText: String {
        switch core.voiceState {
        case .idle: return "Ready"
        case .listening: return "Listening…"
        case .thinking: return "Thinking…"
        case .speaking: return "Speaking…"
        }
    }
}

// MARK: - Key Cap

struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, DS.padS)
            .padding(.vertical, DS.padXS)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .foregroundColor(DS.textSecondary)
    }
}
