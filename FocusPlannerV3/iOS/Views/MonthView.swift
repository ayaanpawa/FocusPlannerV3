import SwiftUI

struct MonthView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var displayedMonth = Date()

    private let cal        = Calendar.current
    private let weekLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ZStack {
            Color.fpBg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                weekdayBar
                Divider().background(Color.fpDivider)
                monthGrid
                Divider().background(Color.fpDivider)
                upcomingPanel
            }
        }
    }

    // MARK: - Header (serif month title + nav)

    private var headerBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.fpHeadline(34))
                .foregroundStyle(Color.fpInk)
                .italic(false)
            Spacer()
            HStack(spacing: 18) {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                }
                Button { jumpToToday() } label: {
                    Text("Today")
                        .font(.fpMono(11, weight: .medium))
                }
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(Color.fpInkMuted)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 18)
    }

    private var weekdayBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.fpMono(10, weight: .medium))
                    .foregroundStyle(Color.fpInkSubtle)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 24)
    }

    // MARK: - Grid

    private var monthGrid: some View {
        GeometryReader { geo in
            let days = calendarDays(for: displayedMonth)
            let rows = max(days.count / 7, 1)
            let rowH = geo.size.height / CGFloat(rows)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: 0
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    MonthDayCell(
                        date:        day,
                        isToday:     day.map { cal.isDateInToday($0) } ?? false,
                        isSelected:  {
                            guard let d = day else { return false }
                            return cal.isDate(d, inSameDayAs: store.selectedDate)
                        }(),
                        isInMonth:   day.map { cal.isDate($0, equalTo: displayedMonth, toGranularity: .month) } ?? false,
                        items:       day.map { store.itemsOn($0) } ?? [],
                        customItems: day.map { store.customItemsOn($0) } ?? [],
                        periods:     store.periods
                    )
                    .frame(height: rowH)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let d = day {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                store.selectedDate = d
                                store.activeTab    = 1
                            }
                        }
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.fpDivider.opacity(0.6))
                            .frame(height: 0.5)
                    }
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.fpDivider.opacity(0.6))
                            .frame(width: 0.5)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Upcoming panel (replicates the bottom strip in the reference design)

    private var upcomingPanel: some View {
        let entries = store.mergedHomework()
            .filter { !$0.isComplete && $0.dueDate >= cal.startOfDay(for: Date()) }
            .prefix(3)

        return VStack(spacing: 0) {
            if entries.isEmpty {
                Text("No upcoming work")
                    .font(.fpMono(11))
                    .foregroundStyle(Color.fpInkSubtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 22)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(entries)) { entry in
                        UpcomingRow(entry: entry)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
            }
        }
        .frame(maxHeight: 220)
    }

    // MARK: - Helpers

    private func shiftMonth(_ dir: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = cal.date(byAdding: .month, value: dir, to: displayedMonth)!
        }
    }

    private func jumpToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth     = Date()
            store.selectedDate = Date()
        }
    }

    private func calendarDays(for month: Date) -> [Date?] {
        let start   = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let range   = cal.range(of: .day, in: .month, for: month)!
        let leading = cal.component(.weekday, from: start) - 1

        var days: [Date?] = Array(repeating: nil, count: leading)
        for i in range {
            days.append(cal.date(byAdding: .day, value: i - 1, to: start))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

// MARK: - Month Day Cell

struct MonthDayCell: View {
    let date:        Date?
    let isToday:     Bool
    let isSelected:  Bool
    let isInMonth:   Bool
    let items:       [CanvasPlannerItem]
    let customItems: [CustomItem]
    let periods:     [Period]

    private struct Chip: Identifiable {
        let id = UUID()
        let title: String
        let color: Color
        let done:  Bool
    }

    private var dayNum: String {
        guard let d = date else { return "" }
        return Calendar.current.component(.day, from: d).description
    }

    private func color(canvas item: CanvasPlannerItem) -> Color {
        periods.first { $0.courseId == item.courseId }?.color
            ?? (item.isCalendarEvent ? .fpAccent : .fpGreen)
    }
    private func color(custom item: CustomItem) -> Color {
        periods.first { $0.id == item.periodId }?.color
            ?? (item.kind == .test ? .fpMustard : .fpGreen)
    }

    private var chips: [Chip] {
        var out: [Chip] = []
        for i in items {
            out.append(Chip(title: i.title, color: color(canvas: i), done: i.isComplete))
        }
        for i in customItems {
            out.append(Chip(title: i.title, color: color(custom: i), done: i.isComplete))
        }
        return out
    }

    var body: some View {
        if date != nil {
            ZStack {
                if isToday {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.fpAccent, lineWidth: 1.5)
                        .padding(4)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.fpInk.opacity(0.05))
                        .padding(4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Spacer()
                        Text(dayNum)
                            .font(.fpMono(12, weight: isToday ? .bold : .regular))
                            .foregroundStyle(
                                isToday    ? Color.fpAccent :
                                !isInMonth ? Color.fpInkSubtle.opacity(0.4) :
                                             Color.fpInk
                            )
                    }

                    if isInMonth {
                        ForEach(chips.prefix(3)) { chip in
                            HStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(chip.color)
                                    .frame(width: 2.5, height: 9)
                                Text(chip.title)
                                    .font(.fpMono(9))
                                    .foregroundStyle(chip.done ? Color.fpInkSubtle : Color.fpInk)
                                    .strikethrough(chip.done)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        if chips.count > 3 {
                            Text("+\(chips.count - 3) more")
                                .font(.fpMono(8))
                                .foregroundStyle(Color.fpInkSubtle)
                                .padding(.leading, 5)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            Color.clear
        }
    }
}

// MARK: - Upcoming Row

private struct UpcomingRow: View {
    @EnvironmentObject private var store: PlannerStore
    let entry: PlannerEntry

    private var period: Period? {
        switch entry {
        case .canvas(let i): return store.period(for: i.courseId)
        case .custom(let i): return store.period(forID: i.periodId)
        }
    }

    private var title: String {
        switch entry {
        case .canvas(let i): return i.title
        case .custom(let i): return i.title
        }
    }

    private var dueText: String {
        let cal  = Calendar.current
        let days = cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to:   cal.startOfDay(for: entry.dueDate)).day ?? 0
        let time = entry.dueDate.formatted(date: .omitted, time: .shortened)
        if days < 0  { return "Overdue · \(time)" }
        if days == 0 { return "Due today, \(time)" }
        if days == 1 { return "Tomorrow" }
        if days <= 6 { return entry.dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }
        return entry.dueDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private var isUrgent: Bool {
        Calendar.current.isDateInToday(entry.dueDate) || entry.dueDate < Date()
    }

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(period?.color ?? Color.fpInkMuted)
                .frame(width: 3, height: 36)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.fpBody(14, weight: .semibold))
                    .foregroundStyle(Color.fpInk)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let p = period {
                        Text("P\(p.number) \(p.name)")
                            .font(.fpMono(11))
                            .foregroundStyle(Color.fpInkMuted)
                    }
                    Text("·")
                        .font(.fpMono(11))
                        .foregroundStyle(Color.fpInkSubtle)
                    Text(dueText)
                        .font(.fpMono(11))
                        .foregroundStyle(isUrgent ? Color.fpAccent : Color.fpInkMuted)
                }
            }
            Spacer()
        }
    }
}
