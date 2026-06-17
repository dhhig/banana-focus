import SwiftUI
import AppKit

@main
struct FocusGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .frame(minWidth: 680, idealWidth: 720, minHeight: 560, idealHeight: 620)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.center()
                        window.title = "剥香蕉 · 专注学习"
                        window.titlebarAppearsTransparent = false
                        window.isMovableByWindowBackground = true
                        window.setFrameAutosaveName("FocusGuardMainWindow")
                    }
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Menu bar extra — shows timer during focus
        MenuBarExtra("FocusGuard", systemImage: "timer") {
            MenuBarView()
                .environmentObject(sessionManager)
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar when window is closed
        return false
    }
}
