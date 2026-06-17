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
        VStack(spacing: 24) {
            Spacer()

            // Large banana logo
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 100, height: 100)

                Text("🍌")
                    .font(.system(size: 44))
            }

            VStack(spacing: 8) {
                Text("🍌 准备剥香蕉")
                    .font(.title3.bold())

                if sessionManager.consecutiveDaysMet > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("连续 \(sessionManager.consecutiveDaysMet) 天剥完香蕉")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Stats summary
            HStack(spacing: 32) {
                StatBadge(
                    label: "今日",
                    value: sessionManager.todayTotalSeconds.formattedShort,
                    icon: "sun.max.fill",
                    color: .yellow
                )
                StatBadge(
                    label: "本周",
                    value: sessionManager.weekTotalSeconds.formattedShort,
                    icon: "calendar",
                    color: .blue
                )
                StatBadge(
                    label: "总计",
                    value: sessionManager.allTimeTotalSeconds.formattedShort,
                    icon: "clock.fill",
                    color: .purple
                )
            }

            // Daily goal
            VStack(spacing: 6) {
                HStack {
                    Text("今日目标")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(sessionManager.todayTotalSeconds.formattedShort) / \(sessionManager.settings.dailyGoalMinutes)分")
                        .font(.caption.bold())
                }
                ProgressView(value: sessionManager.todayGoalProgress)
                    .tint(sessionManager.todayGoalProgress >= 1.0 ? Color.green : Color.accentColor)
            }
            .frame(width: 240)

            // Help text
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.caption)
                Text("前往「选择」标签页选择学习应用并开始")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .padding(.top, 8)

            // Settings gear
            Button {
                showingSettings = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
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
            // Grace warning banner
            if sessionManager.showGraceWarning && sessionManager.sessionPhase == .grace {
                graceBanner
            }

            Spacer()

            // Timer
            VStack(spacing: 8) {
                Text(sessionManager.elapsedSeconds.formattedTimer)
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .foregroundColor(
                        sessionManager.sessionPhase == .grace ? .orange : .primary
                    )

                if let tag = sessionManager.currentSubjectTag.nilIfEmpty {
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.15))
                        )
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

            // End session button
            Button {
                sessionManager.endSession()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                    Text("结束学习")
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.8))
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)

            Text("切换至非学习应用将导致计时作废")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Grace Banner

    private var graceBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("检测到切换应用！")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
                Text("请在 \(sessionManager.graceRemaining) 秒内切回学习应用，否则学习作废")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Countdown
            Text("\(sessionManager.graceRemaining)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .stroke(Color.orange, lineWidth: 2)
                )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
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

                    // Overlay
                    SettingsSection(title: "屏幕暗化", icon: "rectangle.fill.on.rectangle.fill") {
                        VStack(spacing: 8) {
                            Toggle("启用暗化蒙层", isOn: Binding(
                                get: { sessionManager.settings.overlayEnabled },
                                set: { v in
                                    sessionManager.settings.overlayEnabled = v
                                    sessionManager.saveSettings()
                                }
                            ))
                            if sessionManager.settings.overlayEnabled {
                                HStack {
                                    Text("蒙层透明度")
                                    Spacer()
                                    Slider(value: Binding(
                                        get: { sessionManager.settings.overlayOpacity },
                                        set: { v in
                                            sessionManager.settings.overlayOpacity = v
                                            sessionManager.saveSettings()
                                        }
                                    ), in: 0.3...0.9, step: 0.05)
                                    Text("\(Int(sessionManager.settings.overlayOpacity * 100))%")
                                        .frame(width: 36, alignment: .trailing)
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

