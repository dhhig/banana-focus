import SwiftUI

struct SetupView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var allApps: [StudyApp] = []
    @State private var searchText: String = ""
    @State private var isLoading = true
    @State private var hasLoaded = false

    private var filteredApps: [StudyApp] {
        sessionManager.filteredApps(allApps, query: searchText)
    }

    private var selectedCount: Int {
        allApps.filter { $0.isSelected }.count
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
                    Button {
                        searchText = ""
                    } label: {
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
            if isLoading {
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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            AppRowView(app: app) { toggledApp in
                                toggleApp(toggledApp)
                            }
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(.top, 8)
            }

            // Footer with actions
            footerBar
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            Task { await loadApps() }
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
            Text("选中你要用于学习的 App（建议选 2 个用于分屏学习）。切换或打开其他任何应用都会导致香蕉没剥完就断掉！")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.06))
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            // Selection count
            Text("已选 \(selectedCount) 个应用")
                .font(.callout)
                .foregroundColor(selectedCount > 0 ? .accentColor : .secondary)

            Spacer()

            // Quick select suggestions
            Menu("快速选择") {
                Button("全选") { selectAll() }
                Button("取消全选") { deselectAll() }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .opacity(0.7)

            // Subject tag
            TextField("学科标签 (可选)", text: $sessionManager.currentSubjectTag)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)

            // Start button
            Button {
                startFocus()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("开始专注")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selectedCount > 0 ? Color.accentColor : Color.gray.opacity(0.3))
                )
                .foregroundColor(selectedCount > 0 ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.05))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Actions

    private func toggleApp(_ app: StudyApp) {
        if let idx = allApps.firstIndex(where: { $0.id == app.id }) {
            allApps[idx].isSelected.toggle()
        }
    }

    private func selectAll() {
        for i in allApps.indices { allApps[i].isSelected = true }
    }

    private func deselectAll() {
        for i in allApps.indices { allApps[i].isSelected = false }
    }

    private func startFocus() {
        let selected = allApps.filter { $0.isSelected }
        sessionManager.startSession(apps: selected)
    }

    private func loadApps() async {
        isLoading = true
        // Run on background queue
        let apps = await Task.detached(priority: .userInitiated) {
            return AppDiscoveryService().discoverApps()
        }.value
        allApps = apps
        isLoading = false
    }
}

// MARK: - App Row

struct AppRowView: View {
    let app: StudyApp
    let onToggle: (StudyApp) -> Void

    var body: some View {
        Button {
            onToggle(app)
        } label: {
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

                // App name
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(app.id)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Selection indicator
                Image(systemName: app.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(app.isSelected ? .accentColor : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
