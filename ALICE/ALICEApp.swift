//
//  ALICEApp.swift
//  ALICE — AI companion for macOS
//
//  Menu-bar-only application. No dock icon, no main window.
//  All interaction happens through the floating orb overlay and voice.
//

import SwiftUI

@main
struct ALICEApp: App {
    @NSApplicationDelegateAdaptor(ALICEAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class ALICEAppDelegate: NSObject, NSApplicationDelegate {
    private var orbManager: OrbWindowManager!
    private var core: ALICECore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ponytail: no main window — LSUIElement=true handles this in Info.plist
        // but we also hide any window that might appear
        NSApp.windows.forEach { $0.close() }

        ALICEAnalytics.configure()
        ALICEAnalytics.trackAppOpened()

        core = ALICECore()
        orbManager = OrbWindowManager(core: core)
        core.bind(orbManager: orbManager)
        core.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        core.stop()
    }
}
