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
final class OrbWindowManager: ObservableObject {
    private var overlayPanel: NSPanel?
    private var hostingView: NSHostingView<OrbOverlayView>?
    private let core: ALICECore

    init(core: ALICECore) {
        self.core = core
        setupOverlay()
    }

    private func setupOverlay() {
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

    /// Animate the orb to a pointer tag location on screen.
    func animateToPoint(_ tag: PointerTag) async {
        // ponytail: the orb overlay reads core state for position.
        // For pointing, we set a transient pointing target on core
        // that the SwiftUI view animates to, then reverts.
        core.setPointingTarget(tag)
    }
}

// MARK: - SwiftUI Overlay View

struct OrbOverlayView: View {
    @ObservedObject var core: ALICECore

    @State private var orbPosition: CGPoint = CGPoint(x: 200, y: 200)
    @State private var displayTranscript = false
    @State private var pointingTarget: CGPoint?
    @State private var isPointing = false

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

            // Pointing indicator
            if isPointing, let target = pointingTarget {
                PointingIndicator(at: target)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.3), value: core.voiceState)
        .onChange(of: core.pointingTarget) { _, newTag in
            if let tag = newTag {
                handlePointing(tag)
            }
        }
    }

    private func startPositionTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard !isPointing else { return } // ponytail: don't move orb while pointing
                let mouse = NSEvent.mouseLocation
                let screenFrame = NSScreen.main?.frame ?? .zero
                let swiftUIY = screenFrame.height - mouse.y
                let targetX = mouse.x + 60
                let targetY = swiftUIY
                orbPosition.x += (targetX - orbPosition.x) * 0.1
                orbPosition.y += (targetY - orbPosition.y) * 0.1
            }
        }
    }

    private func handlePointing(_ tag: PointerTag) {
        // ponytail: map tag coordinates to screen space and animate
        let screenFrame = NSScreen.main?.frame ?? .zero
        // tag.x is in display points from left, tag.y is from bottom (AppKit origin)
        let swiftUIY = screenFrame.height - tag.y
        pointingTarget = CGPoint(x: tag.x, y: swiftUIY)
        isPointing = true

        // Move orb to the target too
        withAnimation(.easeInOut(duration: 0.4)) {
            orbPosition = CGPoint(x: tag.x + DS.orbSize, y: swiftUIY)
        }

        // Reset after 3 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            isPointing = false
            pointingTarget = nil
            core.clearPointingTarget()
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
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: DS.orbSize + DS.orbGlowRadius * 2, height: DS.orbSize + DS.orbGlowRadius * 2)
                .blur(radius: DS.orbGlowRadius)

            Circle()
                .fill(color)
                .frame(width: DS.orbSize, height: DS.orbSize)
                .scaleEffect(scale)
                .shadow(color: color.opacity(0.6), radius: 10)

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

// MARK: - Pointing Indicator

struct PointingIndicator: View {
    let at: CGPoint

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.orbIdle.opacity(0.2))
                .frame(width: 40, height: 40)
                .scaleEffect(pulse ? 1.5 : 1.0)
                .opacity(pulse ? 0 : 0.6)

            Circle()
                .stroke(DS.orbIdle, lineWidth: 2)
                .frame(width: 20, height: 20)

            // Arrow/pointer
            Image(systemName: "hand.point.right.fill")
                .font(.system(size: 16))
                .foregroundColor(DS.orbIdle)
        }
        .position(at)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}