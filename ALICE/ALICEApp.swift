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
    private var menuBarController: MenuBarController!
    private var core: ALICECore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.windows.forEach { $0.close() }

        ALICEAnalytics.configure()
        ALICEAnalytics.trackAppOpened()

        core = ALICECore()
        orbManager = OrbWindowManager(core: core)
        core.bind(orbManager: orbManager)
        core.start()

        // ponytail: menu bar controller created after core so it can observe core state
        menuBarController = MenuBarController(core: core)
    }

    func applicationWillTerminate(_ notification: Notification) {
        core.stop()
    }
}