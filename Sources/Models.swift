import Foundation
import SwiftUI
import AppKit

// MARK: - Study App (whitelisted app)

struct StudyApp: Identifiable, Codable, Hashable {
    let id: String          // bundleIdentifier
    let name: String        // display name
    let path: String        // full path to .app
    var isSelected: Bool = false

    var icon: NSImage? {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StudyApp, rhs: StudyApp) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Study Session

struct StudySession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let durationSeconds: Int
    let apps: [String]           // bundle IDs of allowed apps
    let appNames: [String]       // display names of allowed apps
    let status: SessionStatus
    let subjectTag: String
    let pomodoroCyclesCompleted: Int

    enum SessionStatus: String, Codable {
        case completed    // manually ended by user
        case failed       // switched to non-whitelisted app
        case abandoned    // user quit without ending
    }

    var formattedDuration: String {
        let h = durationSeconds / 3600
        let m = (durationSeconds % 3600) / 60
        let s = durationSeconds % 60
        if h > 0 {
            return String(format: "%d时%d分%d秒", h, m, s)
        } else if m > 0 {
            return String(format: "%d分%d秒", m, s)
        } else {
            return String(format: "%d秒", s)
        }
    }

    var statusIcon: String {
        switch status {
        case .completed: return "✅"
        case .failed:    return "❌"
        case .abandoned: return "⚠️"
        }
    }

    var statusText: String {
        switch status {
        case .completed: return "完成"
        case .failed:    return "切屏作废"
        case .abandoned: return "中断"
        }
    }
}

// MARK: - Daily Stats

struct DailyStats: Codable {
    let date: String             // "yyyy-MM-dd"
    var totalSeconds: Int = 0
    var completedSessions: Int = 0
    var failedSessions: Int = 0
    var goalMet: Bool = false
}

// MARK: - App Settings (persisted)

struct AppSettings: Codable {
    var gracePeriodSeconds: Int = 5
    var pomodoroEnabled: Bool = false
    var pomodoroFocusMinutes: Int = 25
    var pomodoroBreakMinutes: Int = 5
    var dailyGoalMinutes: Int = 120
    var overlayOpacity: Double = 0.65
    var overlayEnabled: Bool = true
    var autoLaunchApps: Bool = false
    var pauseOnLock: Bool = true

    static let `default` = AppSettings()
}

// MARK: - Pomodoro State

enum PomodoroPhase: String, Codable {
    case focusing
    case breaking
}

struct PomodoroState {
    var phase: PomodoroPhase = .focusing
    var cyclesCompleted: Int = 0
    var currentPhaseSecondsRemaining: Int = 0
    var isActive: Bool = false
}

// MARK: - Shared Helpers

extension Int {
    var formattedShort: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        if h > 0 { return "\(h)时\(m)分" }
        return "\(m)分"
    }

    var formattedTimer: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var formattedFull: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        if h > 0 {
            return String(format: "%d时%02d分%02d秒", h, m, s)
        } else if m > 0 {
            return String(format: "%d分%02d秒", m, s)
        } else {
            return String(format: "%d秒", s)
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
