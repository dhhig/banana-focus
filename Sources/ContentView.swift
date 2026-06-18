import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedTab: Tab = .focus

    enum Tab: String, CaseIterable {
        case focus = "专注", setup = "选择", history = "历史"
        var icon: String {
            switch self {
            case .focus: return "timer"
            case .setup: return "checklist"
            case .history: return "chart.bar.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                switch selectedTab {
                case .focus:  FocusView()
                case .setup:  SetupView()
                case .history: HistoryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Beautiful tab bar
            tabBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .background(
                        selectedTab == tab
                            ? VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(height: 2.5)
                                    .cornerRadius(1.5)
                            }
                            : nil
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .background(
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }
}
