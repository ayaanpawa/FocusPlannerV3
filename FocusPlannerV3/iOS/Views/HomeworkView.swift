import SwiftUI

enum HWFilter: String, CaseIterable {
    case all    = "All"
    case todo   = "To Do"
    case done   = "Done"
}

struct HomeworkView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var filter: HWFilter = .todo
    @State private var showAdd          = false
    @State private var editingCustom: CustomItem? = nil
    @State private var detailItem: CanvasPlannerItem? = nil

    private var filteredEntries: [PlannerEntry] {
        let merged = store.mergedHomework()
        switch filter {
        case .all:  return merged
        case .todo: return merged.filter { !$0.isComplete }
        case .done: return merged.filter {  $0.isComplete }
        }
    }
    private var nothingToShow: Bool { filteredEntries.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color.fpDivider)
            filterBar
            Divider().background(Color.fpDivider)
            Group {
                if store.isLoading && nothingToShow {
                    ProgressView("Loading from Canvas…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = store.errorMsg, nothingToShow {
                    ErrorBanner(message: err) {
                        Task { await store.fetch() }
                    }
                } else {
                    homeworkList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fpBg)
        .sheet(isPresented: $showAdd) {
            AddItemSheet(kind: .homework, date: Date())
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

    private var headerBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Homework")
                .font(.fpHeadline(28))
                .foregroundStyle(Color.fpInk)
            Spacer()
            HStack(spacing: 14) {
                Button { Task { await store.fetch() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fpInkMuted)
                }
                .buttonStyle(.plain)
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fpInkMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var filterBar: some View {
        Picker("Filter", selection: $filter) {
            ForEach(HWFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.fpBg)
    }

    private var homeworkList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if nothingToShow {
                    Text(filter == .done ? "Nothing completed yet." : "You're all caught up.")
                        .font(.fpMono(12))
                        .foregroundStyle(Color.fpInkSubtle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else {
                    ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { idx, entry in
                        if idx > 0 {
                            Divider()
                                .background(Color.fpDivider)
                                .padding(.horizontal, 16)
                        }
                        switch entry {
                        case .canvas(let item):
                            HomeworkRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { detailItem = item }
                        case .custom(let item):
                            CustomHomeworkRow(item: item) { editingCustom = item }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fpBg)
    }
}

// MARK: - Shared Homework Row

struct HomeworkRow: View {
    @EnvironmentObject private var store: PlannerStore
    let item: CanvasPlannerItem

    private var period: Period? { store.period(for: item.courseId) }

    var body: some View {
        HStack(spacing: 14) {
            // Complete toggle
            Button {
                Task { await store.toggleComplete(item) }
            } label: {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.isComplete ? Color.fpGreen : Color.fpInkSubtle)
            }
            .buttonStyle(.plain)

            // Color bar
            Rectangle()
                .fill(period?.color ?? Color.fpInkMuted)
                .frame(width: 3, height: 38)
                .cornerRadius(1.5)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.fpBody(15, weight: .semibold))
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
                    Text(dueDateLabel(item.dueDate))
                        .font(.fpMono(11))
                        .foregroundStyle(isUrgent ? Color.fpAccent : Color.fpInkMuted)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    private var isUrgent: Bool {
        !item.isComplete &&
        (Calendar.current.isDateInToday(item.dueDate) || item.dueDate < Date())
    }

    private func dueDateLabel(_ date: Date) -> String {
        let cal  = Calendar.current
        let days = cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to:   cal.startOfDay(for: date)).day ?? 0
        let time = date.formatted(date: .omitted, time: .shortened)
        if days < 0  { return "Overdue" }
        if days == 0 { return "Due today, \(time)" }
        if days == 1 { return "Tomorrow" }
        if days <= 6 { return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let retry:   () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fpBg)
    }
}

// MARK: - Custom homework row

struct CustomHomeworkRow: View {
    @EnvironmentObject private var store: PlannerStore
    let item:   CustomItem
    let onEdit: () -> Void

    private var period: Period? { store.period(forID: item.periodId) }
    private var urg:    Urgency { urgency(for: item.dueDate) }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                store.toggleCustomComplete(item)
            } label: {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.isComplete ? Color.fpGreen : Color.fpInkSubtle)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(period?.color ?? Color.fpInkMuted)
                .frame(width: 3, height: 38)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.fpBody(15, weight: .semibold))
                    .strikethrough(item.isComplete)
                    .foregroundStyle(item.isComplete ? Color.fpInkSubtle : Color.fpInk)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let p = period {
                        Text("P\(p.number) \(p.name)")
                            .font(.fpMono(11))
                            .foregroundStyle(Color.fpInkMuted)
                    } else {
                        Text("Added by you")
                            .font(.fpMono(11))
                            .foregroundStyle(Color.fpInkMuted)
                    }
                    Text("·")
                        .font(.fpMono(11))
                        .foregroundStyle(Color.fpInkSubtle)
                    Text(dueLabel(item.dueDate))
                        .font(.fpMono(11))
                        .foregroundStyle(isUrgent ? Color.fpAccent : Color.fpInkMuted)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }

    private var isUrgent: Bool {
        !item.isComplete &&
        (Calendar.current.isDateInToday(item.dueDate) || item.dueDate < Date())
    }

    private func dueLabel(_ date: Date) -> String {
        let cal  = Calendar.current
        let days = cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to:   cal.startOfDay(for: date)).day ?? 0
        let time = date.formatted(date: .omitted, time: .shortened)
        if days < 0  { return "Overdue"  }
        if days == 0 { return "Due today, \(time)" }
        if days == 1 { return "Tomorrow" }
        if days <= 6 { return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
