import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedTab: Tab = .focus

    enum Tab: String, CaseIterable {
        case focus = "专注"
        case setup = "选择"
        case history = "历史"

        var icon: String {
            switch self {
            case .focus: return "timer"
            case .setup: return "checklist"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Content area
            Group {
                switch selectedTab {
                case .focus:
                    FocusView()
                case .setup:
                    SetupView()
                case .history:
                    HistoryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Tab bar
            tabBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            HStack {
                Text("🍌")
                    .font(.title2)
                Text("剥香蕉")
                    .font(.title2.bold())
                Spacer()

                // Today's progress indicator
                if sessionManager.sessionPhase == .focusing {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("专注中")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else if sessionManager.sessionPhase == .grace {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("宽限期 \(sessionManager.graceRemaining)s")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if sessionManager.sessionPhase == .idle {
                    // Today's progress
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.caption)
                        Text("今日 \(sessionManager.todayTotalSeconds.formattedShort)")
                            .font(.caption)
                        Text("/ \(sessionManager.settings.dailyGoalMinutes)分")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
            }

            // Daily goal progress bar
            if sessionManager.sessionPhase == .idle {
                ProgressView(value: sessionManager.todayGoalProgress)
                    .tint(
                        sessionManager.todayGoalProgress >= 1.0
                            ? Color.green
                            : Color.accentColor
                    )
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == tab ? "\(tab.icon)" : tab.icon)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .background(
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }
}
