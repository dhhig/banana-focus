import SwiftUI

// MARK: - Motivational Quotes
let QUOTES: [(String, String)] = [
    ("日拱一卒，功不唐捐。", "胡适"),
    ("不积跬步，无以至千里。", "荀子"),
    ("学如逆水行舟，不进则退。", "《增广贤文》"),
    ("知之者不如好之者，好之者不如乐之者。", "孔子"),
    ("业精于勤，荒于嬉。", "韩愈"),
    ("千里之行，始于足下。", "老子"),
    ("学而不思则罔，思而不学则殆。", "孔子"),
    ("宝剑锋从磨砺出，梅花香自苦寒来。", "《警世贤文》"),
    ("天才就是百分之九十九的汗水加百分之一的灵感。", "爱迪生"),
    ("今天不想跑，所以才去跑。", "村上春树"),
    ("只要功夫深，铁杵磨成针。", "谚语"),
    ("少壮不努力，老大徒伤悲。", "《长歌行》"),
    ("书山有路勤为径，学海无涯苦作舟。", "韩愈"),
    ("每一个不曾起舞的日子，都是对生命的辜负。", "尼采"),
    ("生活不止眼前的苟且，还有诗和远方。", "高晓松"),
]

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var timeRange: TimeRange = .day
    @State private var selectedMonth: String = ""
    @State private var selectedYear: String = ""
    @State private var celebQuote: (String, String) = ("", "")
    @State private var showCelebration = false

    enum TimeRange: String, CaseIterable {
        case day = "日", week = "周", month = "月", year = "年"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Time range picker
                pickerBar

                // Summary header
                summaryHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Divider().padding(.top, 8)

                // Main content area
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Session list below
                sessionListCompact
            }

            // Celebration overlay
            if showCelebration {
                CelebrationOverlay(quote: celebQuote) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showCelebration = false
                    }
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
            }
        }
        .onAppear {
            selectedMonth = sessionManager.monthKey(Date())
            selectedYear = sessionManager.yearKey(Date())
            checkGoalCelebration()
        }
        .onChange(of: timeRange) { _ in checkGoalCelebration() }
    }

    // MARK: - Picker

    private var pickerBar: some View {
        HStack(spacing: 2) {
            ForEach(TimeRange.allCases, id: \.self) { r in
                Button {
                    withAnimation { timeRange = r }
                } label: {
                    Text(r.rawValue)
                        .font(.subheadline.weight(timeRange == r ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(timeRange == r
                            ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.15))
                            : nil)
                        .foregroundColor(timeRange == r ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            if timeRange == .month {
                monthNav
            } else if timeRange == .year {
                yearNav
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var monthNav: some View {
        HStack(spacing: 2) {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").font(.caption) }
            Menu(sessionManager.aggregateForMonth(selectedMonth).label) {
                ForEach(sessionManager.availableMonths, id: \.self) { m in
                    Button(sessionManager.aggregateForMonth(m).label) { selectedMonth = m }
                }
                if sessionManager.availableMonths.isEmpty {
                    Button(sessionManager.aggregateForMonth(selectedMonth).label) {}
                }
                Divider()
                Button("本月") { selectedMonth = sessionManager.monthKey(Date()) }
            }
            .menuStyle(.borderlessButton).font(.caption)
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").font(.caption) }
        }
        .buttonStyle(.plain)
    }

    private var yearNav: some View {
        HStack(spacing: 2) {
            Button { shiftYear(-1) } label: { Image(systemName: "chevron.left").font(.caption) }
            Menu(selectedYear + "年") {
                ForEach(sessionManager.availableYears, id: \.self) { y in
                    Button(y + "年") { selectedYear = y }
                }
                if sessionManager.availableYears.isEmpty {
                    Button(selectedYear + "年") {}
                }
                Divider()
                Button("今年") { selectedYear = sessionManager.yearKey(Date()) }
            }
            .menuStyle(.borderlessButton).font(.caption)
            Button { shiftYear(1) } label: { Image(systemName: "chevron.right").font(.caption) }
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ d: Int) {
        guard let date = sessionManager.dateFromKey(selectedMonth + "-01"),
              let nd = Calendar.current.date(byAdding: .month, value: d, to: date) else { return }
        selectedMonth = sessionManager.monthKey(nd)
    }
    private func shiftYear(_ d: Int) {
        if let y = Int(selectedYear) { selectedYear = String(y + d) }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        let (total, completed, failed, days, months) = aggregate
        return HStack(spacing: 8) {
            headerCard(title: periodTitle, value: total.formattedShort,
                       sub: "学习时长", color: .accentColor)
            headerCard(title: timeRange == .year ? "活跃月" : "学习天",
                       value: "\(timeRange == .year ? months : days)",
                       sub: timeRange == .year ? "个月有学习" : "天有学习",
                       color: .green)
            headerCard(title: "完成/作废",
                       value: "\(completed)/\(failed)",
                       sub: "次学习记录", color: .blue)
        }
    }

    private func headerCard(title: String, value: String, sub: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.callout.bold()).foregroundColor(color)
            Text(sub).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.06)))
    }

    private var periodTitle: String {
        switch timeRange {
        case .day: return "今日"
        case .week: return "本周"
        case .month: return sessionManager.aggregateForMonth(selectedMonth).label
        case .year: return selectedYear + "年"
        }
    }

    private typealias Agg = (total: Int, completed: Int, failed: Int, days: Int, months: Int)
    private var aggregate: Agg {
        switch timeRange {
        case .day:
            let s = sessionManager.dailyStats[sessionManager.dateKey(Date())]
            return (s?.totalSeconds ?? 0, s?.completedSessions ?? 0,
                    s?.failedSessions ?? 0, s != nil && (s?.totalSeconds ?? 0) > 0 ? 1 : 0, 1)
        case .week:
            let b = sessionManager.weekBreakdown
            return (b.reduce(0){$0+$1.seconds}, b.reduce(0){$0+$1.completedSessions},
                    b.reduce(0){$0+$1.failedSessions}, b.filter{$0.seconds>0}.count, 1)
        case .month:
            let a = sessionManager.aggregateForMonth(selectedMonth)
            return (a.totalSeconds, a.completedSessions, a.failedSessions, a.daysStudied, 1)
        case .year:
            let a = sessionManager.aggregateForYear(selectedYear)
            return (a.totalSeconds, a.completedSessions, a.failedSessions, a.daysStudied, a.monthsStudied)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch timeRange {
        case .day:  dayTimelineView
        case .week: weekBarView
        case .month: monthCalendarView
        case .year: yearSummaryView
        }
    }

    // MARK: ── DAY: 24-hour Timeline ──

    private var dayTimelineView: some View {
        let todaySessions = sessionManager.sessions.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: Date())
        }
        let goalSec = sessionManager.settings.dailyGoalMinutes * 60
        let doneSec = sessionManager.todayTotalSeconds
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let currentHour = cal.component(.hour, from: now)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Goal progress card ──
                VStack(spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("🎯").font(.caption)
                            Text("今日目标").font(.caption.bold())
                        }
                        Spacer()
                        Text("\(sessionManager.settings.dailyGoalMinutes) 分钟")
                            .font(.caption.bold()).foregroundColor(.accentColor)
                    }
                    HStack {
                        Text("已完成").font(.caption2).foregroundColor(.secondary)
                        Text(doneSec.formattedTimer)
                            .font(.system(.caption, design: .monospaced)).fontWeight(.medium)
                            .foregroundColor(doneSec >= goalSec && goalSec > 0 ? .green : .primary)
                        Spacer()
                        if doneSec < goalSec {
                            Text("还需 \(((goalSec - doneSec) / 60)) 分钟")
                                .font(.caption2).foregroundColor(.orange)
                        }
                    }
                    ProgressView(value: min(1.0, Double(doneSec) / Double(max(goalSec, 1))))
                        .tint(doneSec >= goalSec && goalSec > 0 ? Color.green : Color.accentColor)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.05)))
                .padding(.horizontal, 20).padding(.top, 10)

                // ── 24h Timeline ──
                HStack {
                    Text("🕐 全天时间线")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("可学习时段 8:00-23:00").font(.caption2).foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 6)

                ForEach(0..<24, id: \.self) { hour in
                    let slotStart = cal.date(byAdding: .hour, value: hour, to: todayStart)!
                    let slotEnd = cal.date(byAdding: .hour, value: 1, to: slotStart)!
                    let inSlot = todaySessions.filter { s in
                        let st = s.startTime
                        return st < slotEnd && (s.endTime ?? st) >= slotStart
                    }
                    let isStudyHour = hour >= 8 && hour <= 23
                    let isNow = hour == currentHour

                    HStack(spacing: 8) {
                        // Time label
                        HStack(spacing: 2) {
                            if isNow { Circle().fill(Color.accentColor).frame(width: 5, height: 5) }
                            Text(String(format: "%02d:00", hour))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(isNow ? .accentColor : .secondary)
                        }
                        .frame(width: 42, alignment: .trailing)

                        // Bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(hour: hour, inSlot: inSlot, isStudyHour: isStudyHour, isNow: isNow))
                            .frame(height: 16)
                            .overlay(
                                HStack {
                                    if !inSlot.isEmpty {
                                        let secs = inSlot.filter{$0.status == .completed}.reduce(0){$0+$1.durationSeconds}
                                        if secs > 0 {
                                            Text("📚 " + secs.formattedShort)
                                                .font(.system(size: 8)).foregroundColor(.white)
                                        } else if inSlot.contains(where: {$0.status == .failed}) {
                                            Text("❌ 作废").font(.system(size: 8)).foregroundColor(.white.opacity(0.8))
                                        }
                                    } else if hour == 8 {
                                        Text(goalSec > 0 ? "🎯 目标 \(sessionManager.settings.dailyGoalMinutes)分" : "🎯 设定目标开始学习")
                                            .font(.system(size: 8)).foregroundColor(.accentColor.opacity(0.7))
                                    }
                                    Spacer()
                                }.padding(.horizontal, 6),
                                alignment: .leading
                            )
                    }
                    .padding(.horizontal, 20)
                    .opacity(isStudyHour ? 1.0 : 0.55)
                }

                // Bottom message
                if todaySessions.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("🍌").font(.largeTitle)
                            Text("今天还没有学习记录").font(.caption).foregroundColor(.secondary)
                            Text("去「选择」页面开始专注，这里会显示你的学习时间线").font(.caption2).foregroundColor(.secondary)
                        }.padding(.vertical, 24)
                        Spacer()
                    }
                }
            }.padding(.bottom, 20)
        }
    }

    private func barColor(hour: Int, inSlot: [StudySession], isStudyHour: Bool, isNow: Bool) -> Color {
        if !inSlot.isEmpty {
            return inSlot.contains(where: {$0.status == .completed})
                ? Color.green.opacity(0.45)
                : Color.red.opacity(0.3)
        }
        if isNow { return Color.accentColor.opacity(0.15) }
        if isStudyHour { return Color.secondary.opacity(0.06) }
        return Color.secondary.opacity(0.03)
    }

    // MARK: ── WEEK: Bar Chart ──

    private var weekBarView: some View {
        let data = sessionManager.weekBreakdown
        let maxVal = max(data.map{$0.seconds}.max() ?? 1, 1)
        let goalSec = sessionManager.settings.dailyGoalMinutes * 60

        return ScrollView {
            VStack(spacing: 6) {
                ForEach(data) { day in
                    HStack(spacing: 6) {
                        Text(day.label).font(.caption2).foregroundColor(.secondary).frame(width: 62, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)).frame(height: 20)
                                let w = maxVal > 0 ? CGFloat(day.seconds) / CGFloat(maxVal) * geo.size.width : 0
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(day.seconds >= goalSec && goalSec > 0 ? Color.green.opacity(0.7) : Color.accentColor.opacity(0.5))
                                    .frame(width: max(w, day.seconds > 0 ? 4 : 0), height: 20)
                                if goalSec > 0 {
                                    Rectangle().fill(Color.orange.opacity(0.4))
                                        .frame(width: 1, height: 20)
                                        .offset(x: CGFloat(goalSec) / CGFloat(maxVal) * geo.size.width)
                                }
                            }
                        }.frame(height: 20)

                        Text(day.seconds > 0 ? day.seconds.formattedShort : "")
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)
                }
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.accentColor.opacity(0.5)).frame(width: 10, height: 10)
                        Text("学习时长").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Rectangle().fill(Color.orange.opacity(0.4)).frame(width: 10, height: 1)
                        Text("目标线").font(.caption2).foregroundColor(.secondary)
                    }
                }.padding(.leading, 68).padding(.top, 4)
            }.padding(.top, 16).padding(.bottom, 20)
        }
    }

    // MARK: ── MONTH: Calendar Grid ──

    private var monthCalendarView: some View {
        let cal = Calendar.current
        guard let startDate = sessionManager.dateFromKey(selectedMonth + "-01"),
              let range = cal.range(of: .day, in: .month, for: startDate),
              let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: startDate)) else {
            return AnyView(Text("日期错误").font(.caption).padding())
        }
        let firstWeekday = cal.component(.weekday, from: firstDay) // Sun=1, Mon=2, ...
        let offset = (firstWeekday + 5) % 7 // Make Mon=0
        let today = Date()
        let goalSec = sessionManager.settings.dailyGoalMinutes * 60

        return AnyView(ScrollView {
            VStack(spacing: 0) {
                // Day headers
                HStack(spacing: 0) {
                    ForEach(["一","二","三","四","五","六","日"], id: \.self) { d in
                        Text(d).font(.caption2.bold()).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)

                // Grid
                let total = range.count + offset
                let rows = (total + 6) / 7

                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < offset || idx >= total {
                                Text("").frame(maxWidth: .infinity, minHeight: 44)
                            } else {
                                let day = idx - offset + 1
                                let key = String(format: "%@-%02d", selectedMonth, day)
                                let stats = sessionManager.dailyStats[key]
                                let isToday = cal.isDate(today, inSameDayAs: cal.date(from: DateComponents(
                                    year: Int(selectedMonth.prefix(4)),
                                    month: Int(selectedMonth.suffix(2)),
                                    day: day
                                )) ?? Date.distantPast)
                                let isWeekend = col >= 5 // Sat=5, Sun=6
                                let goalMet = (stats?.totalSeconds ?? 0) >= goalSec && goalSec > 0
                                let hasStudy = (stats?.totalSeconds ?? 0) > 0

                                VStack(spacing: 1) {
                                    Text("\(day)")
                                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                                        .foregroundColor(
                                            isToday ? .accentColor
                                                : isWeekend ? .secondary.opacity(0.6)
                                                : .primary
                                        )
                                        .frame(width: 24, height: 18)
                                        .background(
                                            isToday ? Circle().fill(Color.accentColor.opacity(0.2))
                                                : nil
                                        )

                                    if hasStudy {
                                        Text(goalMet ? "🍌" : "⏳")
                                            .font(.system(size: goalMet ? 15 : 9))
                                    } else {
                                        Text("·").font(.system(size: 8)).foregroundColor(.secondary.opacity(0.3))
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            isToday ? Color.accentColor.opacity(0.08)
                                                : isWeekend ? Color.secondary.opacity(0.04)
                                                : hasStudy ? Color.yellow.opacity(0.06)
                                                : Color.clear
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Legend + info
                VStack(spacing: 4) {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.accentColor.opacity(0.2)).frame(width: 8, height: 8)
                            Text("今天").font(.caption2).foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Text("🍌").font(.caption2)
                            Text("目标达成").font(.caption2).foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Text("⏳").font(.caption2)
                            Text("有学习").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    if sessionManager.dailyBreakdownForMonth(selectedMonth).allSatisfy({ $0.seconds == 0 }) {
                        Text("这个月还没有学习记录，开始你的第一次专注吧！🍌")
                            .font(.caption2).foregroundColor(.secondary).padding(.top, 4)
                    }
                }.padding(.top, 8)
            }.padding(.bottom, 20)
        })
    }

    // MARK: ── YEAR: Monthly Summary ──

    private var yearSummaryView: some View {
        let months = sessionManager.monthlyBreakdownForYear(selectedYear)
        let maxVal = max(months.map{$0.totalSeconds}.max() ?? 1, 1)
        let goalPerMonth = sessionManager.settings.dailyGoalMinutes * 60 * 25 // ~25 study days

        return ScrollView {
            VStack(spacing: 0) {
                // Year goal card
                VStack(spacing: 4) {
                    HStack {
                        Text("📊 \(selectedYear)年学习总览").font(.caption.bold())
                        Spacer()
                        let yearAgg = sessionManager.aggregateForYear(selectedYear)
                        Text(yearAgg.totalSeconds > 0 ? yearAgg.totalSeconds.formattedShort : "暂无记录")
                            .font(.caption.bold()).foregroundColor(.accentColor)
                    }
                    if months.allSatisfy({ $0.totalSeconds == 0 }) {
                        Text("开始学习后，这里会显示每个月的学习时长和达标情况")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.05)))
                .padding(.horizontal, 20).padding(.top, 10)

                // Month list
                LazyVStack(spacing: 4) {
                    ForEach(months) { m in
                        HStack(spacing: 8) {
                            // Month label
                            Text(m.label.replacingOccurrences(of: selectedYear+"年", with: "")
                                    .replacingOccurrences(of: "月", with: "月"))
                                .font(.caption).foregroundColor(.secondary)
                                .frame(width: 48, alignment: .leading)

                            // Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.secondary.opacity(0.06))
                                        .frame(height: 22)

                                    // Filled bar
                                    let w = maxVal > 0 ? CGFloat(m.totalSeconds) / CGFloat(maxVal) * geo.size.width : 0
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(m.totalSeconds > 0
                                            ? Color.accentColor.opacity(0.55)
                                            : Color.clear)
                                        .frame(width: max(w, m.totalSeconds > 0 ? 3 : 0), height: 22)

                                    // Target line
                                    if goalPerMonth > 0 && maxVal > 0 {
                                        let goalX = CGFloat(goalPerMonth) / CGFloat(maxVal) * geo.size.width
                                        if goalX < geo.size.width {
                                            Rectangle()
                                                .fill(Color.orange.opacity(0.35))
                                                .frame(width: 1, height: 22)
                                                .offset(x: goalX)
                                        }
                                    }
                                }
                            }.frame(height: 22)

                            // Stats
                            HStack(spacing: 2) {
                                if m.totalSeconds > 0 {
                                    Text(m.totalSeconds.formattedShort)
                                        .font(.system(size: 9, design: .monospaced))
                                    Text("·").font(.caption2).foregroundColor(.secondary)
                                    Text("\(m.daysStudied)天").font(.caption2)
                                    if m.daysStudied >= 25 {
                                        Text("🍌").font(.caption)
                                    } else if m.daysStudied >= 15 {
                                        Text("⏳").font(.caption)
                                    } else if m.daysStudied > 0 {
                                        Text("🌱").font(.caption)
                                    }
                                } else {
                                    Text("—").font(.caption2).foregroundColor(.secondary.opacity(0.5))
                                }
                            }.frame(width: 88, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                    }
                }.padding(.top, 12)

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Rectangle().fill(Color.orange.opacity(0.35)).frame(width: 10, height: 1)
                        Text("月目标").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("🌱").font(.caption2)
                        Text("开始").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("⏳").font(.caption2)
                        Text("积累").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("🍌").font(.caption2)
                        Text("达成").font(.caption2).foregroundColor(.secondary)
                    }
                }.padding(.top, 8).padding(.bottom, 20)
            }
        }
    }

    // MARK: - Session List

    private var sessionListCompact: some View {
        VStack(spacing: 0) {
            Divider()
            if !sessionManager.sessions.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sessionManager.sessions.prefix(10)) { s in
                            SessionRowView(session: s)
                            Divider().padding(.leading, 46)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Celebration

    private func checkGoalCelebration() {
        if timeRange == .day && sessionManager.todayGoalProgress >= 1.0
            && sessionManager.settings.dailyGoalMinutes > 0
            && sessionManager.todayTotalSeconds > 0 {
            celebQuote = QUOTES.randomElement() ?? QUOTES[0]
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCelebration = true
            }
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showCelebration = false
                }
            }
        }
    }
}

// MARK: - Celebration Overlay

struct CelebrationOverlay: View {
    let quote: (String, String)
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.3
    @State private var bananaRotation: Double = 0
    @State private var sparkles: [(Double, Double, Double)] = []

    init(quote: (String, String), onDismiss: @escaping () -> Void) {
        self.quote = quote
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Card
            VStack(spacing: 12) {
                // Animated banana
                ZStack {
                    // Glow
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 90, height: 90)
                        .scaleEffect(1.0 + 0.2 * sin(bananaRotation * .pi / 180))

                    // Big banana
                    Text("🍌")
                        .font(.system(size: 64))
                        .rotationEffect(.degrees(bananaRotation))
                        .scaleEffect(scale)

                    // Sparkle particles
                    ForEach(Array(sparkles.enumerated()), id: \.offset) { i, s in
                        Text(["✨","⭐","🌟","💫","🎉"][i % 5])
                            .font(.system(size: 16 + s.2 * 20))
                            .offset(x: cos(s.0) * 70 * s.2, y: sin(s.0) * 70 * s.2)
                            .opacity(1.0 - s.2)
                    }
                }
                .frame(height: 120)

                // Congratulations
                Text("🎉 香蕉剥完啦！")
                    .font(.title3.bold())

                Text("今日目标已达成")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Quote
                VStack(spacing: 4) {
                    Text("「\(quote.0)」")
                        .font(.callout)
                        .italic()
                        .multilineTextAlignment(.center)
                    Text("—— \(quote.1)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text("继续加油！💪")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 5)
            )
            .frame(width: 320)
            .scaleEffect(scale)
            .onAppear {
                // Animate in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    scale = 1.0
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    bananaRotation = 10
                }
                // Generate sparkle particles
                var p: [(Double, Double, Double)] = []
                for i in 0..<8 {
                    let angle = Double(i) * .pi * 2 / 8
                    p.append((angle, Double.random(in: 0...1), 0))
                }
                sparkles = p
                // Animate particles outward
                for i in 0..<8 {
                    withAnimation(.easeOut(duration: 1.5).delay(Double(i) * 0.15)) {
                        sparkles[i].2 = 1.0
                    }
                }
            }
        }
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: StudySession
    var body: some View {
        HStack(spacing: 10) {
            Text(session.statusIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.appNames.joined(separator: " + ")).font(.caption).lineLimit(1)
                HStack(spacing: 4) {
                    Text(session.startTime.formatted(date: .numeric, time: .shortened))
                        .font(.caption2).foregroundColor(.secondary)
                    Text("·").foregroundColor(.secondary)
                    Text(session.formattedDuration).font(.caption2)
                        .foregroundColor(session.status == .completed ? .green : .secondary)
                }
            }
            Spacer()
            Text(session.statusText).font(.caption2)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(session.status == .completed
                    ? Color.green.opacity(0.12) : Color.red.opacity(0.08)))
                .foregroundColor(session.status == .completed ? .green : .red)
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }
}

