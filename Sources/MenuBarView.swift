import SwiftUI
import AppKit

/// Menu bar extra view shown when clicking the menubar icon.
struct MenuBarView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("🍌")
                Text("剥香蕉")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if sessionManager.sessionPhase == .focusing {
                // Active session info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("专注中")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Spacer()
                        Text(sessionManager.elapsedSeconds.formattedTimer)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                    }

                    if let tag = sessionManager.currentSubjectTag.nilIfEmpty {
                        Text("学科: \(tag)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("应用: \(sessionManager.selectedApps.map { $0.name }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                Button {
                    sessionManager.endSession()
                } label: {
                    HStack {
                        Image(systemName: "stop.circle")
                        Text("结束学习")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

            } else if sessionManager.sessionPhase == .grace {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("宽限期!")
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(sessionManager.graceRemaining)s")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    Text("请切回学习应用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            } else {
                // Idle
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日: \(sessionManager.todayTotalSeconds.formattedShort)")
                        .font(.subheadline)
                    if sessionManager.consecutiveDaysMet > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("连续 \(sessionManager.consecutiveDaysMet) 天")
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            // Quick actions
            Button {
                showMainWindow()
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("打开主窗口")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("退出 剥香蕉")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 260)
    }

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.contains("剥香蕉") }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
