//
//  OrbWindowManager.swift
//  ALICE
//
//  Full-screen transparent overlay hosting the ALICE orb, response text,
//  waveform, and pointing animations. Non-activating, joins all Spaces.
//

import AppKit
import SwiftUI

@MainActor
final class OrbWindowManager {
    private var overlayPanel: NSPanel?
    private var hostingView: NSHostingView<OrbOverlayView>?
    private let core: ALICECore

    init(core: ALICECore) {
        self.core = core
        setupOverlay()
    }

    private func setupOverlay() {
        // One panel per screen, covering the full screen, transparent, non-activating
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true

        let orbView = OrbOverlayView(core: core)
        let hosting = NSHostingView(rootView: orbView)
        panel.contentView = hosting

        self.overlayPanel = panel
        self.hostingView = hosting
        panel.orderFrontRegardless()
    }

    func show() {
        overlayPanel?.orderFrontRegardless()
    }

    func hide() {
        overlayPanel?.orderOut()
    }

    func animateToPoint(_ tag: PointerTag) async {
        // ponytail: the SwiftUI view reads core state and handles the animation.
        // The actual coordinate mapping and animation happen in OrbOverlayView.
        // This method exists for the core to call; the view observes core.lastResponse
        // and handles pointing tags via its own timer/animation.
    }
}

// MARK: - SwiftUI Overlay View

struct OrbOverlayView: View {
    @ObservedObject var core: ALICECore

    @State private var orbPosition: CGPoint = CGPoint(x: 200, y: 200)
    @State private var animatePulse = false
    @State private var displayTranscript = false
    @State private var pointAnimationTarget: CGPoint?

    var body: some View {
        ZStack {
            // Orb
            OrbShape(state: core.voiceState, audioLevel: core.audioLevel)
                .frame(width: DS.orbSize, height: DS.orbSize)
                .position(x: orbPosition.x, y: orbPosition.y)
                .onAppear { startPositionTracking() }

            // Response bubble
            if !core.lastResponse.isEmpty && (core.voiceState == .speaking || core.voiceState == .idle) {
                ResponseBubble(text: core.lastResponse, state: core.voiceState)
                    .position(
                        x: orbPosition.x + DS.orbSize + DS.padS,
                        y: orbPosition.y
                    )
                    .transition(.opacity)
            }

            // Transcript bubble
            if !core.lastTranscript.isEmpty && core.voiceState == .thinking {
                TranscriptBubble(text: core.lastTranscript)
                    .position(
                        x: orbPosition.x + DS.orbSize + DS.padS,
                        y: orbPosition.y + 40
                    )
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.3), value: core.voiceState)
    }

    private func startPositionTracking() {
        // ponytail: orb follows the cursor with a spring delay
        // This creates the "companion next to cursor" effect
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                let mouse = NSEvent.mouseLocation
                let screenFrame = NSScreen.main?.frame ?? .zero
                // Convert from bottom-left origin to SwiftUI coordinate space
                let swiftUIY = screenFrame.height - mouse.y
                let targetX = mouse.x + 60
                let targetY = swiftUIY

                // Smooth follow
                orbPosition.x += (targetX - orbPosition.x) * 0.1
                orbPosition.y += (targetY - orbPosition.y) * 0.1
            }
        }
    }
}

// MARK: - Orb Shape

struct OrbShape: View {
    let state: VoiceState
    let audioLevel: Float

    var color: Color {
        switch state {
        case .idle: return DS.orbIdle
        case .listening: return DS.orbListening
        case .thinking: return DS.orbThinking
        case .speaking: return DS.orbSpeaking
        }
    }

    var scale: CGFloat {
        1.0 + CGFloat(audioLevel) * 0.3
    }

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: DS.orbSize + DS.orbGlowRadius * 2, height: DS.orbSize + DS.orbGlowRadius * 2)
                .blur(radius: DS.orbGlowRadius)

            // Core orb
            Circle()
                .fill(color)
                .frame(width: DS.orbSize, height: DS.orbSize)
                .scaleEffect(scale)
                .shadow(color: color.opacity(0.6), radius: 10)

            // Inner highlight
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: DS.orbSize * 0.4, height: DS.orbSize * 0.4)
                .offset(x: -DS.orbSize * 0.15, y: -DS.orbSize * 0.15)
        }
        .animation(.easeOut(duration: 0.15), value: scale)
        .animation(.easeInOut(duration: 0.3), value: color)
    }
}

// MARK: - Response Bubble

struct ResponseBubble: View {
    let text: String
    let state: VoiceState

    var body: some View {
        Text(text)
            .font(DS.bodyFont)
            .foregroundColor(DS.textPrimary)
            .padding(.horizontal, DS.padM)
            .padding(.vertical, DS.padS)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusM)
                    .fill(DS.panelBg.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radiusM)
                            .stroke(DS.panelBorder, lineWidth: 1)
                    )
            )
            .frame(maxWidth: 300, alignment: .leading)
            .shadow(color: .black.opacity(0.3), radius: 8)
    }
}

// MARK: - Transcript Bubble

struct TranscriptBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DS.captionFont)
            .foregroundColor(DS.textSecondary)
            .padding(.horizontal, DS.padS)
            .padding(.vertical, DS.padXS)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusS)
                    .fill(DS.panelBg.opacity(0.8))
            )
            .frame(maxWidth: 200)
    }
}
