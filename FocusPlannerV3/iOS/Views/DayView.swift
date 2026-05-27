import SwiftUI

struct DayView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var addingKind: CustomItemKind? = nil
    @State private var editingCustom: CustomItem?  = nil
    @State private var detailItem: CanvasPlannerItem? = nil

    private let cal = Calendar.current

    private var dayEntries: [PlannerEntry] { store.mergedItemsOn(store.selectedDate) }
    private var dayHomework: [PlannerEntry] { dayEntries.filter { $0.isHomework } }
    private var dayTests:    [PlannerEntry] { dayEntries.filter { $0.isTest } }
    private var isEmpty: Bool { dayEntries.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            dateNavBar
            Divider()
            actionRow
            Divider()

            if isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        if !dayTests.isEmpty {
                            section(title: "Tests & Quizzes", icon: "bolt.fill", color: .orange) {
                                ForEach(dayTests) { entry in
                                    switch entry {
                                    case .canvas(let item):
                                        DayPanelRow(item: item, kind: .test)
                                            .contentShape(Rectangle())
                                            .onTapGesture { detailItem = item }
                                    case .custom(let item):
                                        CustomDayRow(item: item) { editingCustom = item }
                                    }
                                }
                            }
                        }
                        if !dayHomework.isEmpty {
                            section(title: "Homework", icon: "doc.text.fill", color: .green) {
                                ForEach(dayHomework) { entry in
                                    switch entry {
                                    case .canvas(let item):
                                        DayPanelRow(item: item, kind: .homework)
                                            .contentShape(Rectangle())
                                            .onTapGesture { detailItem = item }
                                    case .custom(let item):
                                        CustomDayRow(item: item) { editingCustom = item }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fpBg)
        .sheet(item: $addingKind) { kind in
            AddItemSheet(kind: kind, date: store.selectedDate)
                .environmentObject(store)
        }
        .sheet(item: $editingCustom) { item in
            AddItemSheet(editing: item)
                .environmentObject(store)
        }
        .sheet(item: $detailItem) { item in
            ItemDetailView(item: item)
                .environmentObject(store)
        }
    }

    // MARK: - Action buttons

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button { addingKind = .homework } label: {
                Label("Add Homework", systemImage: "doc.badge.plus")
                    .font(.fpBody(13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.fpDivider, lineWidth: 1)
                    )
                    .foregroundStyle(Color.fpInk)
            }
            .buttonStyle(.plain)

            Button { addingKind = .test } label: {
                Label("Add Test", systemImage: "bolt.fill")
                    .font(.fpBody(13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.fpInk, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color.fpBg)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Date nav (prev / next day)

    private var dateNavBar: some View {
        HStack(spacing: 0) {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fpInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(store.selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.fpHeadline(20))
                    .foregroundStyle(Color.fpInk)
                if !cal.isDateInToday(store.selectedDate) {
                    Button("Today") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.selectedDate = Date()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.fpMono(11, weight: .medium))
                    .foregroundStyle(Color.fpAccent)
                }
            }

            Spacer()

            Button { shift(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fpInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.fpBg)
    }

    private func shift(_ days: Int) {
        withAnimation(.easeInOut(duration: 0.15)) {
            store.selectedDate = cal.date(byAdding: .day, value: days, to: store.selectedDate) ?? store.selectedDate
        }
    }

    // MARK: - Section helper

    @ViewBuilder
    private func section<Content: View>(
        title: String, icon: String, color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                    .kerning(0.6)
            }
            VStack(spacing: 8) { content() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow.opacity(0.7))
            Text("Nothing due today")
                .font(.system(size: 17, weight: .semibold))
            Text("Enjoy the free time!")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fpBg)
    }
}

// MARK: - DayPanelRow (Canvas item in the Day tab)

struct DayPanelRow: View {
    enum Kind { case homework, test }

    @EnvironmentObject private var store: PlannerStore
    let item: CanvasPlannerItem
    let kind: Kind

    private var period: Period? { store.period(for: item.courseId) }

    var body: some View {
        HStack(spacing: 14) {
            if kind == .homework {
                Button {
                    Task { await store.toggleComplete(item) }
                } label: {
                    Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(item.isComplete ? Color.fpGreen : Color.fpInkSubtle)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.fpMustard)
                    .frame(width: 18)
            }

            Rectangle()
                .fill(period?.color ?? Color.fpInkMuted)
                .frame(width: 3, height: 36)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.fpBody(14, weight: .semibold))
                    .strikethrough(item.isComplete)
                    .foregroundStyle(item.isComplete ? Color.fpInkSubtle : Color.fpInk)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let p = period {
                        Text("P\(p.number) \(p.name)")
                            .font(.fpMono(11))
                            .foregroundStyle(Color.fpInkMuted)
                    } else if let ctx = item.contextName {
                        Text(ctx)
                            .font(.fpMono(11))
                            .foregroundStyle(Color.fpInkMuted)
                    }
                    Text("·")
                        .font(.fpMono(11))
                        .foregroundStyle(Color.fpInkSubtle)
                    Text(item.dueDate.formatted(date: .omitted, time: .shortened))
                        .font(.fpMono(11))
                        .foregroundStyle(Color.fpInkMuted)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Custom item row (manual additions)

struct CustomDayRow: View {
    @EnvironmentObject private var store: PlannerStore
    let item:    CustomItem
    let onEdit:  () -> Void

    private var period: Period? { store.period(forID: item.periodId) }

    var body: some View {
        HStack(spacing: 14) {
            if item.kind == .homework {
                Button { store.toggleCustomComplete(item) } label: {
                    Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(item.isComplete ? Color.fpGreen : Color.fpInkSubtle)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.fpMustard)
                    .frame(width: 18)
            }

            Rectangle()
                .fill(period?.color ?? Color.fpInkMuted)
                .frame(width: 3, height: 36)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.fpBody(14, weight: .semibold))
                    .strikethrough(item.isComplete)
                    .foregroundStyle(item.isComplete ? Color.fpInkSubtle : Color.fpInk)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let p = period {
                        Text("P\(p.number) \(p.name)")
                            .font(.fpMono(11))
                            .foregroundStyle(Color.fpInkMuted)
                    }
                    if item.kind == .test {
                        Text("·")
                            .font(.fpMono(11))
                            .foregroundStyle(Color.fpInkSubtle)
                        Text(item.testSubtype.rawValue)
                            .font(.fpMono(11, weight: .medium))
                            .foregroundStyle(Color.fpAccent)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.deleteCustomItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
