//
//  MenuBarController.swift
//  ALICE
//
//  NSStatusItem + custom NSPanel lifecycle for the menu bar dropdown.
//

import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private let core: ALICECore

    init(core: ALICECore) {
        self.core = core
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // ponytail: use SF Symbol for the menu bar icon
        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "circle.fill",
                accessibilityDescription: "ALICE"
            )
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePanel)
            button.target = self
        }

        self.statusItem = item
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem?.button else { return }

        let panelView = OrbPanelView(core: core) {
            NSApp.terminate(nil)
        }
        let hostingController = NSHostingController(rootView: panelView)

        let panel = NSPanel(
            contentViewController: hostingController,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position below the status item
        if let screen = button.window?.screen {
            let buttonFrame = button.window?.frame ?? .zero
            let panelSize = NSSize(width: 300, height: 400)
            var origin = NSPoint(
                x: buttonFrame.midX - panelSize.width / 2,
                y: buttonFrame.minY - panelSize.height - 8
            )
            // Clamp to screen
            origin.x = max(screen.visibleFrame.minX, min(origin.x, screen.visibleFrame.maxX - panelSize.width))
            origin.y = max(screen.visibleFrame.minY, origin.y)
            panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        }

        self.panel = panel
        panel.orderFrontRegardless()

        // Click outside to dismiss
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let panel = self?.panel, panel.isVisible {
                if !panel.contains(event.locationInWindow) {
                    self?.hidePanel()
                }
            }
            return event
        }
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        panel = nil
    }
}
