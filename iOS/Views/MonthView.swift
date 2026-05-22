import SwiftUI

struct MonthView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var displayedMonth = Date()
    @State private var selectedDate:  Date? = nil
    @State private var showDetail     = false

    private let cal = Calendar.current
    private let weekLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                monthHeader
                weekdayBar
                Divider()
                monthGrid
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(monthTitle)
                        .font(.headline)
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showDetail) {
            if let day = selectedDate {
                DayDetailSheet(date: day)
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack(spacing: 20) {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button { jumpToToday() } label: {
                Text("Today")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
            }
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private var weekdayBar: some View {
        HStack(spacing: 0) {
            ForEach(weekLabels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }

    // MARK: - Grid

    private var monthGrid: some View {
        GeometryReader { geo in
            let days   = calendarDays(for: displayedMonth)
            let rows   = days.count / 7
            let cellH  = (geo.size.height) / CGFloat(rows)
            let cellW  = geo.size.width / 7

            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                    spacing: 0
                ) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        MonthDayCell(
                            date:       day,
                            isToday:    day.map { cal.isDateInToday($0) } ?? false,
                            isSelected: day.map { selectedDate.map { cal.isDate($0, inSameDayAs: $1) } ?? false } ?? false,
                            items:      day.map { store.itemsOn($0) } ?? [],
                            periods:    store.periods
                        )
                        .frame(height: cellH)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard let d = day else { return }
                            selectedDate = d
                            showDetail   = true
                        }
                        .overlay(
                            Rectangle()
                                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private func shiftMonth(_ dir: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = cal.date(byAdding: .month, value: dir, to: displayedMonth)!
        }
    }

    private func jumpToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = Date()
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
    let date:       Date?
    let isToday:    Bool
    let isSelected: Bool
    let items:      [CanvasPlannerItem]
    let periods:    [Period]

    private var dayNum: String {
        guard let d = date else { return "" }
        return Calendar.current.component(.day, from: d).description
    }

    private var ab: ABDay? {
        date.flatMap { abDay(for: $0) }
    }

    // Up to 4 distinct period colors for dots
    private var dotColors: [Color] {
        var seen = Set<Int>()
        var colors: [Color] = []
        for item in items {
            let key = item.courseId ?? -item.plannableId
            if !seen.contains(key) {
                seen.insert(key)
                if let p = periods.first(where: { $0.courseId == item.courseId }) {
                    colors.append(p.color)
                } else {
                    colors.append(item.isCalendarEvent ? .purple : .blue)
                }
            }
            if colors.count == 4 { break }
        }
        return colors
    }

    var body: some View {
        if date != nil {
            VStack(alignment: .leading, spacing: 2) {
                // Top row: day number + A/B badge
                HStack(alignment: .top) {
                    ZStack {
                        if isToday {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 22, height: 22)
                        } else if isSelected {
                            Circle()
                                .strokeBorder(Color.blue, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                        Text(dayNum)
                            .font(.system(size: 12, weight: isToday || isSelected ? .bold : .regular))
                            .foregroundStyle(isToday ? .white : isSelected ? .blue : .primary)
                    }
                    Spacer()
                    if let ab = ab {
                        Text(ab.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(ab.color, in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)

                // Colored dots for items
                if !dotColors.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(Array(dotColors.enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(color)
                                .frame(width: 5, height: 5)
                        }
                        if items.count > 4 {
                            Text("+")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 5)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(isToday ? Color.blue.opacity(0.04) : Color(.systemBackground))
        } else {
            Color(.secondarySystemGroupedBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    let date: Date

    var body: some View {
        NavigationView {
            List {
                let dayItems = store.itemsOn(date)
                let hw    = dayItems.filter { $0.isAssignment }
                let tests = dayItems.filter { $0.isCalendarEvent }

                if hw.isEmpty && tests.isEmpty {
                    Text("Nothing due this day.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    if !hw.isEmpty {
                        Section("Homework") {
                            ForEach(hw) { item in
                                HomeworkRow(item: item)
                            }
                        }
                    }
                    if !tests.isEmpty {
                        Section("Tests / Events") {
                            ForEach(tests) { item in
                                TestRow(item: item, compact: true)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
