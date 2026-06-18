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
                .frame(minWidth: 720, idealWidth: 760, minHeight: 680, idealHeight: 720)
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

        // Menu bar extra — shows countdown during focus
        MenuBarExtra {
            MenuBarView()
                .environmentObject(sessionManager)
        } label: {
            let phase = sessionManager.sessionPhase
            let remain = sessionManager.remainingSeconds
            if phase == .focusing || phase == .grace {
                Text("🍌 \(remain.formattedTimer)")
            } else {
                Text("🍌")
            }
        }
    }
}

// MARK: - App Delegate

// MARK: - Menu Bar Label (live countdown)

struct MenuBarLabel: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        if sessionManager.sessionPhase == .focusing || sessionManager.sessionPhase == .grace {
            HStack(spacing: 3) {
                Text("🍌")
                Text(sessionManager.remainingSeconds.formattedTimer)
                    .font(.system(size: 11, design: .monospaced).monospacedDigit())
            }
        } else {
            Text("🍌")
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
