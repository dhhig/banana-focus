import Foundation
import AppKit
import Combine
import CoreGraphics

/// Central manager for focus sessions, app monitoring, and the overlay.
class SessionManager: ObservableObject {

    // MARK: - Published State

    @Published var sessionPhase: SessionPhase = .idle
    @Published var elapsedSeconds: Int = 0
    @Published var currentFrontAppName: String = ""
    @Published var currentFrontAppBundleID: String = ""
    @Published var graceRemaining: Int = 0
    @Published var selectedApps: [StudyApp] = []
    @Published var sessions: [StudySession] = []
    @Published var dailyStats: [String: DailyStats] = [:]
    @Published var consecutiveDaysMet: Int = 0
    @Published var settings: AppSettings = .default
    @Published var pomodoro: PomodoroState = PomodoroState()
    @Published var currentSubjectTag: String = ""
    @Published var showGraceWarning: Bool = false

    // MARK: - Services

    private let overlayService = FocusOverlayService()
    private let appDiscovery = AppDiscoveryService()

    // MARK: - Timers

    private var mainTimer: AnyCancellable?
    private var graceTimer: AnyCancellable?
    private var overlayUpdateTimer: AnyCancellable?
    private var appObserver: NSObjectProtocol?
    private var screenSleepObserver: NSObjectProtocol?
    private var screenWakeObserver: NSObjectProtocol?

    // MARK: - Session Tracking

    private var sessionStartTime: Date = Date()
    private var whitelistedBundleIDs: Set<String> = []
    private var isPausedForLock = false

    enum SessionPhase: String {
        case idle
        case focusing
        case grace
        case paused
    }

    // MARK: - Init

    init() {
        loadSettings()
        loadHistory()
        loadDailyStats()
        calculateStreak()
        setupAppObserver()
    }

    // MARK: - App Monitoring

    private func setupAppObserver() {
        appObserver = NSWorkspace.shared.notificationCenter
            .addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleAppActivation(notification)
            }

        // Pause on screen lock/sleep
        screenSleepObserver = NSWorkspace.shared.notificationCenter
            .addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleScreenSleep()
            }

        screenWakeObserver = NSWorkspace.shared.notificationCenter
            .addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleScreenWake()
            }
    }

    private func handleAppActivation(_ notification: Notification) {
        guard sessionPhase == .focusing || sessionPhase == .grace else { return }

        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }

        currentFrontAppBundleID = bundleID
        currentFrontAppName = app.localizedName ?? bundleID

        // Our own app is always allowed
        let ourBundleID = Bundle.main.bundleIdentifier ?? "com.focusguard.app"
        if bundleID == ourBundleID { return }

        // System processes to ignore (never trigger violation)
        let systemIgnore = [
            "com.apple.loginwindow",
            "com.apple.notificationcenterui",
            "com.apple.controlcenter",
            "com.apple.Spotlight",
            "com.apple.dock",
            "com.apple.systemuiserver",
            "com.apple.WindowManager",
            "com.apple.AccessibilityUIServer",
        ]
        if systemIgnore.contains(bundleID) { return }

        if whitelistedBundleIDs.contains(bundleID) {
            // Switched to a whitelisted app
            if sessionPhase == .grace {
                cancelGrace()
            }
        } else {
            // Switched to a non-whitelisted app → trigger grace or fail immediately
            if settings.gracePeriodSeconds > 0 && sessionPhase == .focusing {
                enterGrace()
            } else {
                failSession(reason: "切换到非学习应用: \(currentFrontAppName)")
            }
        }
    }

    private func handleScreenSleep() {
        guard sessionPhase == .focusing else { return }
        if settings.pauseOnLock {
            isPausedForLock = true
            sessionPhase = .paused
            mainTimer?.cancel()
            overlayUpdateTimer?.cancel()
        }
    }

    private func handleScreenWake() {
        guard isPausedForLock else { return }
        isPausedForLock = false
        sessionPhase = .focusing
        startMainTimer()
        startOverlayUpdates()
    }

    // MARK: - Grace Period

    private func enterGrace() {
        sessionPhase = .grace
        graceRemaining = settings.gracePeriodSeconds
        showGraceWarning = true

        graceTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickGrace()
            }
    }

    private func tickGrace() {
        graceRemaining -= 1
        if graceRemaining <= 0 {
            graceTimer?.cancel()
            showGraceWarning = false
            failSession(reason: "宽限期结束 - 切换到非学习应用: \(currentFrontAppName)")
        }
    }

    private func cancelGrace() {
        graceTimer?.cancel()
        graceRemaining = 0
        showGraceWarning = false
        sessionPhase = .focusing
    }

    // MARK: - Session Control

    func startSession(apps: [StudyApp]) {
        selectedApps = apps
        whitelistedBundleIDs = Set(apps.map { $0.id })
        // Always allow our own app
        if let ourID = Bundle.main.bundleIdentifier {
            whitelistedBundleIDs.insert(ourID)
        }

        sessionStartTime = Date()
        elapsedSeconds = 0
        sessionPhase = .focusing
        graceRemaining = 0
        showGraceWarning = false
        isPausedForLock = false

        // Reset pomodoro if enabled
        if settings.pomodoroEnabled {
            pomodoro = PomodoroState(
                phase: .focusing,
                cyclesCompleted: 0,
                currentPhaseSecondsRemaining: settings.pomodoroFocusMinutes * 60,
                isActive: true
            )
        }

        // Launch apps if enabled
        if settings.autoLaunchApps {
            for app in apps {
                NSWorkspace.shared.openApplication(
                    at: URL(fileURLWithPath: app.path),
                    configuration: NSWorkspace.OpenConfiguration()
                ) { _, _ in }
            }
        }

        // Show overlay
        if settings.overlayEnabled {
            overlayService.show(whitelistedBundleIDs: whitelistedBundleIDs)
            startOverlayUpdates()
        }

        // Start timer
        startMainTimer()

        // Get current frontmost app name
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            currentFrontAppName = frontApp.localizedName ?? ""
            currentFrontAppBundleID = frontApp.bundleIdentifier ?? ""
        }
    }

    func endSession() {
        let duration = elapsedSeconds
        let session = StudySession(
            id: UUID(),
            startTime: sessionStartTime,
            endTime: Date(),
            durationSeconds: duration,
            apps: Array(whitelistedBundleIDs.filter { $0 != Bundle.main.bundleIdentifier }),
            appNames: selectedApps.map { $0.name },
            status: .completed,
            subjectTag: currentSubjectTag,
            pomodoroCyclesCompleted: pomodoro.cyclesCompleted
        )

        sessions.insert(session, at: 0)
        updateDailyStats(seconds: duration, success: true)
        saveHistory()
        saveDailyStats()
        calculateStreak()

        resetSession()
    }

    func failSession(reason: String) {
        let duration = elapsedSeconds
        print("[FocusGuard] Session failed: \(reason)")

        let session = StudySession(
            id: UUID(),
            startTime: sessionStartTime,
            endTime: Date(),
            durationSeconds: duration,
            apps: Array(whitelistedBundleIDs.filter { $0 != Bundle.main.bundleIdentifier }),
            appNames: selectedApps.map { $0.name },
            status: .failed,
            subjectTag: currentSubjectTag,
            pomodoroCyclesCompleted: pomodoro.cyclesCompleted
        )

        sessions.insert(session, at: 0)
        updateDailyStats(seconds: duration, success: false)
        saveHistory()
        saveDailyStats()
        calculateStreak()

        resetSession()
    }

    private func resetSession() {
        mainTimer?.cancel()
        graceTimer?.cancel()
        overlayUpdateTimer?.cancel()
        overlayService.hide()
        sessionPhase = .idle
        elapsedSeconds = 0
        graceRemaining = 0
        showGraceWarning = false
        isPausedForLock = false
        whitelistedBundleIDs = []
        selectedApps = []
        pomodoro = PomodoroState()
    }

    // MARK: - Timer

    private func startMainTimer() {
        mainTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickMainTimer()
            }
    }

    private func tickMainTimer() {
        guard sessionPhase == .focusing else { return }
        elapsedSeconds += 1

        // Pomodoro countdown
        if settings.pomodoroEnabled && pomodoro.isActive {
            pomodoro.currentPhaseSecondsRemaining -= 1
            if pomodoro.currentPhaseSecondsRemaining <= 0 {
                handlePomodoroPhaseEnd()
            }
        }
    }

    private func handlePomodoroPhaseEnd() {
        switch pomodoro.phase {
        case .focusing:
            pomodoro.cyclesCompleted += 1
            pomodoro.phase = .breaking
            pomodoro.currentPhaseSecondsRemaining = settings.pomodoroBreakMinutes * 60
            // Notify about break
            showBreakNotification()
        case .breaking:
            pomodoro.phase = .focusing
            pomodoro.currentPhaseSecondsRemaining = settings.pomodoroFocusMinutes * 60
            // Notify about next focus
            showFocusNotification()
        }
    }

    private func showBreakNotification() {
        // Play system beep for pomodoro break alert
        NSSound.beep()
    }

    private func showFocusNotification() {
        // Play system beep for pomodoro focus alert
        NSSound.beep()
    }

    // MARK: - Overlay Updates

    private func startOverlayUpdates() {
        overlayUpdateTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.overlayService.refreshCutouts()
            }
    }

    // MARK: - Persistence

    private let historyKey = "FocusGuard_SessionHistory"
    private let statsKey = "FocusGuard_DailyStats"
    private let settingsKey = "FocusGuard_Settings"

    func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            settings = .default
            return
        }
        settings = decoded
    }

    func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
        // Apply overlay opacity
        overlayService.opacity = settings.overlayOpacity
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([StudySession].self, from: data) else {
            sessions = []
            return
        }
        sessions = decoded
    }

    private func saveHistory() {
        // Keep last 500 sessions
        let trimmed = Array(sessions.prefix(500))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func loadDailyStats() {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let decoded = try? JSONDecoder().decode([String: DailyStats].self, from: data) else {
            dailyStats = [:]
            return
        }
        dailyStats = decoded
    }

    private func saveDailyStats() {
        guard let data = try? JSONEncoder().encode(dailyStats) else { return }
        UserDefaults.standard.set(data, forKey: statsKey)
    }

    private func updateDailyStats(seconds: Int, success: Bool) {
        let today = dateKey(Date())
        var stats = dailyStats[today] ?? DailyStats(date: today)
        stats.totalSeconds += seconds
        if success {
            stats.completedSessions += 1
        } else {
            stats.failedSessions += 1
        }
        stats.goalMet = stats.totalSeconds >= settings.dailyGoalMinutes * 60
        dailyStats[today] = stats
    }

    private func calculateStreak() {
        let cal = Calendar.current
        var streak = 0
        var date = Date()
        let goalSeconds = settings.dailyGoalMinutes * 60

        while true {
            let key = dateKey(date)
            if let stats = dailyStats[key], stats.totalSeconds >= goalSeconds {
                streak += 1
                date = cal.date(byAdding: .day, value: -1, to: date) ?? date
            } else {
                // Check if today hasn't met goal yet (don't break streak for current day)
                if dateKey(date) == dateKey(Date()) && dailyStats[key] == nil {
                    date = cal.date(byAdding: .day, value: -1, to: date) ?? date
                    continue
                }
                break
            }
        }
        consecutiveDaysMet = streak
    }


    // MARK: - Computed Stats

    var todayTotalSeconds: Int {
        dailyStats[dateKey(Date())]?.totalSeconds ?? 0
    }

    var todayGoalProgress: Double {
        let goal = settings.dailyGoalMinutes * 60
        guard goal > 0 else { return 0 }
        return min(1.0, Double(todayTotalSeconds) / Double(goal))
    }

    var weekTotalSeconds: Int {
        let cal = Calendar.current
        var total = 0
        for i in 0..<7 {
            if let date = cal.date(byAdding: .day, value: -i, to: Date()),
               let stats = dailyStats[dateKey(date)] {
                total += stats.totalSeconds
            }
        }
        return total
    }

    var allTimeTotalSeconds: Int {
        dailyStats.values.reduce(0) { $0 + $1.totalSeconds }
    }

    // MARK: - App Discovery

    func discoverApps() -> [StudyApp] {
        appDiscovery.discoverApps()
    }

    func filteredApps(_ apps: [StudyApp], query: String) -> [StudyApp] {
        appDiscovery.filter(apps, query: query)
    }
}
