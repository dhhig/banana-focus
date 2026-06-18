import SwiftUI
import AppKit

struct FocusView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showingSettings = false
    @State private var isAnimating = false

    var body: some View {
        Group {
            if sessionManager.sessionPhase == .idle {
                idleView
            } else if sessionManager.sessionPhase == .paused {
                pausedView
            } else {
                activeFocusView
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Idle View (no active session)

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero banana
                VStack(spacing: 4) {
                    Text("🍌")
                        .font(.system(size: 56))
                    Text("剥香蕉")
                        .font(.largeTitle.bold())
                    Text("专注学习，每天剥完一根香蕉")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if sessionManager.consecutiveDaysMet > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").foregroundColor(.orange).font(.caption)
                            Text("连续 \(sessionManager.consecutiveDaysMet) 天达成目标")
                                .font(.caption).foregroundColor(.orange)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.top, 20)

                // Stats cards
                HStack(spacing: 12) {
                    StatBadge(label:"今日", value: sessionManager.todayTotalSeconds.formattedShort,
                             icon: "sun.max.fill", color: .orange)
                    StatBadge(label:"本周", value: sessionManager.weekTotalSeconds.formattedShort,
                             icon: "calendar", color: .blue)
                    StatBadge(label:"总计", value: sessionManager.allTimeTotalSeconds.formattedShort,
                             icon: "clock.fill", color: .purple)
                }
                .padding(.horizontal, 20)

                // Daily goal card
                VStack(spacing: 8) {
                    HStack {
                        Label("今日目标", systemImage: "target").font(.subheadline.bold())
                        Spacer()
                        Text("\(sessionManager.todayTotalSeconds.formattedShort) / \(sessionManager.settings.dailyGoalMinutes)分")
                            .font(.subheadline.monospacedDigit())
                    }
                    ProgressView(value: sessionManager.todayGoalProgress)
                        .tint(sessionManager.todayGoalProgress >= 1.0 ? Color.green : Color.accentColor)
                        .scaleEffect(x: 1, y: 1.8, anchor: .center)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.06)))
                .padding(.horizontal, 20)

            // Action buttons
            VStack(spacing: 12) {
                if sessionManager.canQuickStart {
                    Button { sessionManager.quickStart() } label: {
                        Label("快速开始（上次应用）", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }

                Button { sessionManager.startFreeSession() } label: {
                    Label("自由专注（不限App）", systemImage: "timer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor.opacity(0.1)))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                // Duration
                VStack(spacing: 6) {
                    Text("学习时长").font(.subheadline.bold())
                    Slider(value: Binding(
                        get: { Double(sessionManager.settings.sessionDurationMinutes) },
                        set: { v in sessionManager.settings.sessionDurationMinutes = max(5, Int(v)); sessionManager.saveSettings() }
                    ), in: 5...240, step: 5)
                    Text("\(sessionManager.settings.sessionDurationMinutes / 60) 小时 \(sessionManager.settings.sessionDurationMinutes % 60) 分钟")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(.accentColor)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.04)))
            }
            .padding(.horizontal, 20)

            // Settings
            Button { showingSettings = true } label: {
                Label("设置", systemImage: "gearshape")
                    .font(.caption).foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Paused View (screen locked)

    private var pausedView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("已暂停")
                .font(.title3.bold())

            Text("屏幕锁定或休眠，计时已自动暂停。\n解锁后自动恢复。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("已学习: \(sessionManager.elapsedSeconds.formattedTimer)")
                .font(.title2.monospacedDigit())
                .foregroundColor(.accentColor)

            Spacer()
        }
    }

    // MARK: - Active Focus View

    private var activeFocusView: some View {
        VStack(spacing: 0) {
            // Grace warning banner with smooth animation
            if sessionManager.showGraceWarning && sessionManager.sessionPhase == .grace {
                graceBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            // Countdown Timer
            VStack(spacing: 8) {
                // Large countdown
                Text(sessionManager.remainingSeconds.formattedTimer)
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .foregroundColor(
                        sessionManager.remainingSeconds < 60 ? .red
                            : sessionManager.sessionPhase == .grace ? .orange
                            : .primary
                    )

                // Progress bar for countdown
                let totalDur = sessionManager.settings.sessionDurationMinutes * 60
                let progress = totalDur > 0
                    ? Double(sessionManager.remainingSeconds) / Double(totalDur)
                    : 0
                ProgressView(value: progress)
                    .tint(
                        sessionManager.remainingSeconds < 60 ? Color.red
                            : sessionManager.remainingSeconds < 300 ? Color.orange
                            : Color.accentColor
                    )
                    .frame(width: 200)

                // Elapsed + total
                HStack(spacing: 6) {
                    Text("已学 \(sessionManager.elapsedSeconds.formattedShort)")
                        .font(.caption).foregroundColor(.secondary)
                    Text("·").foregroundColor(.secondary)
                    Text("目标 \(sessionManager.settings.sessionDurationMinutes)分")
                        .font(.caption).foregroundColor(.secondary)
                }

                if let tag = sessionManager.currentSubjectTag.nilIfEmpty {
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                }
            }

            // Pomodoro indicator
            if sessionManager.settings.pomodoroEnabled {
                pomodoroIndicator
                    .padding(.top, 16)
            }

            // Current app info
            if !sessionManager.currentFrontAppName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "app.badge.checkmark")
                        .foregroundColor(.secondary)
                    Text("当前: \(sessionManager.currentFrontAppName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }

            // Selected apps chips
            if !sessionManager.selectedApps.isEmpty {
                HStack(spacing: 6) {
                    ForEach(sessionManager.selectedApps, id: \.id) { app in
                        HStack(spacing: 4) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            Text(app.name)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.12))
                        )
                    }
                }
                .padding(.top, 6)
            }

            Spacer()

            // End session button (always visible during focus)
            Button {
                sessionManager.endSession()
            } label: {
                Text("提前结束")
                    .font(.caption)
                    .padding(.horizontal, 20).padding(.vertical, 6)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessionManager.showGraceWarning)
    }

    // MARK: - Grace Banner

    private var graceBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("⚠️ 检测到切屏！")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                    Text("请在 \(sessionManager.graceRemaining) 秒内切回学习应用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Big countdown
                Text("\(sessionManager.graceRemaining)")
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundColor(.orange)
                    .frame(width: 50, height: 50)
                    .background(Circle().stroke(Color.orange, lineWidth: 3))
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    sessionManager.failSession(reason: "用户主动放弃")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("放弃学习")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("切换回学习 App 则自动继续")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Pomodoro Indicator

    private var pomodoroIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: sessionManager.pomodoro.phase == .focusing ? "brain.head.profile" : "cup.and.saucer.fill")
                .foregroundColor(sessionManager.pomodoro.phase == .focusing ? .accentColor : .green)
            Text(sessionManager.pomodoro.phase == .focusing ? "专注" : "休息")
                .font(.caption.bold())
            Text(sessionManager.pomodoro.currentPhaseSecondsRemaining.formattedTimer)
                .font(.caption.monospacedDigit())

            Text("· 第 \(sessionManager.pomodoro.cyclesCompleted + 1) 轮")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 80)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("设置")
                    .font(.title3.bold())
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Daily goal
                    SettingsSection(title: "每日目标", icon: "target") {
                        HStack {
                            Text("每日学习目标 (分钟)")
                            Spacer()
                            Stepper("", value: Binding(
                                get: { sessionManager.settings.dailyGoalMinutes },
                                set: { v in
                                    sessionManager.settings.dailyGoalMinutes = v
                                    sessionManager.saveSettings()
                                }
                            ), in: 10...600, step: 10)
                            Text("\(sessionManager.settings.dailyGoalMinutes) 分")
                                .frame(width: 50, alignment: .trailing)
                        }
                    }

                    // Grace period
                    SettingsSection(title: "宽限期", icon: "hourglass") {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("切屏宽限时间 (秒)")
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { sessionManager.settings.gracePeriodSeconds },
                                    set: { v in
                                        sessionManager.settings.gracePeriodSeconds = v
                                        sessionManager.saveSettings()
                                    }
                                )) {
                                    Text("无宽限").tag(0)
                                    Text("3 秒").tag(3)
                                    Text("5 秒").tag(5)
                                    Text("10 秒").tag(10)
                                }
                                .frame(width: 100)
                            }
                            Text("检测到切屏后给你几秒切回来，超时学习作废。选「无宽限」则一切换立刻作废。")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Pomodoro
                    SettingsSection(title: "番茄钟", icon: "timer") {
                        VStack(spacing: 8) {
                            Toggle("启用番茄钟模式", isOn: Binding(
                                get: { sessionManager.settings.pomodoroEnabled },
                                set: { v in
                                    sessionManager.settings.pomodoroEnabled = v
                                    sessionManager.saveSettings()
                                }
                            ))

                            if sessionManager.settings.pomodoroEnabled {
                                HStack {
                                    Text("专注时长 (分)")
                                    Spacer()
                                    Stepper("", value: Binding(
                                        get: { sessionManager.settings.pomodoroFocusMinutes },
                                        set: { v in
                                            sessionManager.settings.pomodoroFocusMinutes = v
                                            sessionManager.saveSettings()
                                        }
                                    ), in: 15...60, step: 5)
                                    Text("\(sessionManager.settings.pomodoroFocusMinutes) 分")
                                }
                                HStack {
                                    Text("休息时长 (分)")
                                    Spacer()
                                    Stepper("", value: Binding(
                                        get: { sessionManager.settings.pomodoroBreakMinutes },
                                        set: { v in
                                            sessionManager.settings.pomodoroBreakMinutes = v
                                            sessionManager.saveSettings()
                                        }
                                    ), in: 1...30, step: 1)
                                    Text("\(sessionManager.settings.pomodoroBreakMinutes) 分")
                                }
                            }
                        }
                    }

                    // Other
                    SettingsSection(title: "其他", icon: "ellipsis.gearshape") {
                        VStack(spacing: 8) {
                            Toggle("锁屏/休眠时自动暂停", isOn: Binding(
                                get: { sessionManager.settings.pauseOnLock },
                                set: { v in
                                    sessionManager.settings.pauseOnLock = v
                                    sessionManager.saveSettings()
                                }
                            ))
                            Toggle("开始学习时自动启动应用", isOn: Binding(
                                get: { sessionManager.settings.autoLaunchApps },
                                set: { v in
                                    sessionManager.settings.autoLaunchApps = v
                                    sessionManager.saveSettings()
                                }
                            ))
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 460, height: 440)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.subheadline.bold())
            }
            content()
                .padding(.leading, 22)
        }
    }
}
}
