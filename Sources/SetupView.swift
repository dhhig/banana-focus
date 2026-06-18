import SwiftUI

struct SetupView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var searchText: String = ""

    private var filteredApps: [StudyApp] {
        let apps = sessionManager.discoverableApps
        guard !searchText.isEmpty else { return apps }
        let q = searchText.lowercased()
        return apps.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Info banner
            infoBanner

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索应用...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // App list
            if sessionManager.discoverableApps.isEmpty {
                Spacer()
                ProgressView("正在扫描应用...")
                    .progressViewStyle(.circular)
                Spacer()
            } else if filteredApps.isEmpty && !searchText.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("未找到 \"\(searchText)\"")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredApps) { app in
                        HStack(spacing: 12) {
                            // App icon
                            Group {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                } else {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).font(.body).foregroundColor(.primary)
                                Text(app.id).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                            }

                            Spacer()

                            // Toggle button - explicit Button!
                            Button {
                                sessionManager.toggleAppSelection(app)
                            } label: {
                                Image(systemName: app.isSelected
                                    ? "checkmark.circle.fill"
                                    : "circle")
                                    .font(.title3)
                                    .foregroundColor(app.isSelected
                                        ? .accentColor
                                        : .secondary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }

            // Footer
            footerBar
        }
        .onAppear {
            sessionManager.loadDiscoverableApps()
        }
    }

    // MARK: - Info Banner

    private var infoBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("选择你的学习应用")
                    .font(.subheadline.bold())
            }
            Text("勾选你要用于学习的 App（建议选 2 个用于分屏学习）。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.06)))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Footer

    private var footerBar: some View {
        let count = sessionManager.selectedAppCount
        let durBinding = Binding<Double>(
            get: { Double(sessionManager.settings.sessionDurationMinutes) },
            set: { v in
                sessionManager.settings.sessionDurationMinutes = max(5, Int(v))
                sessionManager.saveSettings()
            }
        )

        return HStack {
            Text("已选 \(count) 个").font(.callout)
                .foregroundColor(count > 0 ? .accentColor : .secondary)
            Spacer()

            HStack(spacing: 4) {
                Text("\(sessionManager.settings.sessionDurationMinutes)分")
                    .font(.caption.monospacedDigit()).foregroundColor(.accentColor)
                    .frame(width: 34, alignment: .trailing)
                Slider(value: durBinding, in: 5...240, step: 5).frame(width: 70)
            }

            Button {
                let selected = sessionManager.discoverableApps.filter { $0.isSelected }
                sessionManager.startSession(apps: selected, durationMinutes: sessionManager.settings.sessionDurationMinutes)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("开始专注").fontWeight(.semibold)
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(Capsule().fill(count > 0 ? Color.accentColor : Color.gray.opacity(0.3)))
                .foregroundColor(count > 0 ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(
            Rectangle().fill(Color(nsColor: .separatorColor).opacity(0.05)).frame(height: 1),
            alignment: .top
        )
    }
}
