import Foundation

// MARK: - Aggregated Stats Extensions for SessionManager

extension SessionManager {

    // MARK: - Week Breakdown

    struct DayBreakdown: Identifiable {
        public let id: String
        public let dateKey: String
        public let label: String
        public let seconds: Int
        public let completedSessions: Int
        public let failedSessions: Int
    }

    /// Day-by-day breakdown for the current week (Mon-Sun).
    var weekBreakdown: [DayBreakdown] {
        let cal = Calendar.current
        var result: [DayBreakdown] = []
        let today = Date()
        guard let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return result
        }
        let dayNames = ["周一","周二","周三","周四","周五","周六","周日"]
        let df = DateFormatter()
        df.dateFormat = "M/d"
        for i in 0..<7 {
            guard let date = cal.date(byAdding: .day, value: i, to: monday) else { continue }
            let key = dateKey(date)
            let stats = dailyStats[key]
            result.append(DayBreakdown(
                id: key,
                dateKey: key,
                label: "\(dayNames[i]) \(df.string(from: date))",
                seconds: stats?.totalSeconds ?? 0,
                completedSessions: stats?.completedSessions ?? 0,
                failedSessions: stats?.failedSessions ?? 0
            ))
        }
        return result
    }

    /// Day-by-day breakdown for the current week, summed by weekday name (for when data spans weeks).
    var weekSummary: (totalSeconds: Int, days: [DayBreakdown]) {
        let breakdown = weekBreakdown
        let total = breakdown.reduce(0) { $0 + $1.seconds }
        return (total, breakdown)
    }

    // MARK: - Month

    func monthKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }

    struct MonthAggregate: Identifiable {
        public let id: String       // "yyyy-MM"
        public let label: String    // "2026年6月"
        public let totalSeconds: Int
        public let completedSessions: Int
        public let failedSessions: Int
        public let daysStudied: Int
    }

    func aggregateForMonth(_ month: String) -> MonthAggregate {
        var totalSec = 0, completed = 0, failed = 0
        for (key, stats) in dailyStats where key.hasPrefix(month) {
            totalSec += stats.totalSeconds
            completed += stats.completedSessions
            failed += stats.failedSessions
        }
        let parts = month.split(separator: "-")
        let label = parts.count == 2 ? "\(parts[0])年\(Int(parts[1])!)月" : month
        return MonthAggregate(
            id: month,
            label: label,
            totalSeconds: totalSec,
            completedSessions: completed,
            failedSessions: failed,
            daysStudied: dailyStats.filter { $0.key.hasPrefix(month) && $0.value.totalSeconds > 0 }.count
        )
    }

    func dailyBreakdownForMonth(_ month: String) -> [DayBreakdown] {
        let cal = Calendar.current
        var result: [DayBreakdown] = []
        guard let startDate = dateFromKey(month + "-01") else { return result }
        guard let range = cal.range(of: .day, in: .month, for: startDate) else { return result }

        for day in range {
            let key = String(format: "%@-%02d", month, day)
            let stats = dailyStats[key]
            result.append(DayBreakdown(
                id: key,
                dateKey: key,
                label: "\(day)日",
                seconds: stats?.totalSeconds ?? 0,
                completedSessions: stats?.completedSessions ?? 0,
                failedSessions: stats?.failedSessions ?? 0
            ))
        }
        return result
    }

    // MARK: - Year

    func yearKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }

    struct YearAggregate {
        public let yearKey: String
        public let label: String
        public let totalSeconds: Int
        public let completedSessions: Int
        public let failedSessions: Int
        public let daysStudied: Int
        public let monthsStudied: Int
    }

    func aggregateForYear(_ year: String) -> YearAggregate {
        var totalSec = 0, completed = 0, failed = 0, daysCount = 0
        var monthsSet = Set<String>()
        for (key, stats) in dailyStats where key.hasPrefix(year) {
            totalSec += stats.totalSeconds
            completed += stats.completedSessions
            failed += stats.failedSessions
            if stats.totalSeconds > 0 {
                daysCount += 1
                monthsSet.insert(String(key.prefix(7)))
            }
        }
        return YearAggregate(
            yearKey: year,
            label: "\(year)年",
            totalSeconds: totalSec,
            completedSessions: completed,
            failedSessions: failed,
            daysStudied: daysCount,
            monthsStudied: monthsSet.count
        )
    }

    func monthlyBreakdownForYear(_ year: String) -> [MonthAggregate] {
        let months = ["01","02","03","04","05","06","07","08","09","10","11","12"]
        return months.map { aggregateForMonth("\(year)-\($0)") }
    }

    // MARK: - Available periods

    var availableMonths: [String] {
        var months = Set<String>()
        for (key, stats) in dailyStats where stats.totalSeconds > 0 {
            months.insert(String(key.prefix(7)))
        }
        return Array(months).sorted(by: >)
    }

    var availableYears: [String] {
        var years = Set<String>()
        for (key, stats) in dailyStats where stats.totalSeconds > 0 {
            years.insert(String(key.prefix(4)))
        }
        return Array(years).sorted(by: >)
    }

    var currentMonthAggregate: MonthAggregate {
        aggregateForMonth(monthKey(Date()))
    }

    var currentYearAggregate: YearAggregate {
        aggregateForYear(yearKey(Date()))
    }

    // MARK: - Helpers

    func dateFromKey(_ key: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = key.count == 10 ? "yyyy-MM-dd" : "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: key)
    }

    public func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
