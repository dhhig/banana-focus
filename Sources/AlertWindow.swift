import SwiftUI
import AppKit

// MARK: - Floating Alert Window

class AlertWindowController: ObservableObject {
    static let shared = AlertWindowController()
    private var alertWindow: NSWindow?

    func show(onContinue: @escaping () -> Void, onQuit: @escaping () -> Void) {
        // Remove existing
        alertWindow?.close()

        let content = SwitchAlertView(
            onContinue: {
                AlertWindowController.shared.hide()
                onContinue()
            },
            onQuit: {
                AlertWindowController.shared.hide()
                onQuit()
            }
        )

        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 160)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false
        window.hasShadow = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = hosting
        window.center()
        window.alphaValue = 0

        // Fade in
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 1.0
        }

        alertWindow = window
    }

    func hide() {
        guard let window = alertWindow else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            window.animator().alphaValue = 0.0
        } completionHandler: {
            window.orderOut(nil)
            self.alertWindow = nil
        }
    }
}

// MARK: - Switch Alert View

struct SwitchAlertView: View {
    let onContinue: () -> Void
    let onQuit: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Text("🍌")
                .font(.system(size: 36))
                .scaleEffect(appear ? 1.0 : 0.5)

            // Message
            VStack(spacing: 4) {
                Text("检测到切屏！")
                    .font(.headline)
                Text("你切换到了非学习应用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Buttons
            HStack(spacing: 16) {
                Button {
                    onQuit()
                } label: {
                    Text("放弃学习")
                        .font(.subheadline.bold())
                        .frame(width: 100, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.12))
                        )
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Button {
                    onContinue()
                } label: {
                    Text("继续学习")
                        .font(.subheadline.bold())
                        .frame(width: 100, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(24)
        .frame(width: 320, height: 160)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        )
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}
