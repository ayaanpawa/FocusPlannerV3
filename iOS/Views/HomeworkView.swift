import SwiftUI

enum HWFilter: String, CaseIterable {
    case all    = "All"
    case todo   = "To Do"
    case done   = "Done"
}

struct HomeworkView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var filter: HWFilter = .todo

    private var filtered: [CanvasPlannerItem] {
        switch filter {
        case .all:  return store.homeworkItems
        case .todo: return store.homeworkItems.filter { !$0.isComplete }
        case .done: return store.homeworkItems.filter {  $0.isComplete }
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if store.isLoading {
                    ProgressView("Loading from Canvas…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = store.errorMsg {
                    ErrorBanner(message: err) {
                        Task { await store.fetch() }
                    }
                } else {
                    homeworkList
                }
            }
            .navigationTitle("Homework")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await store.fetch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Filter", selection: $filter) {
                    ForEach(HWFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).shadow(.drop(radius: 1)))
            }
        }
        .navigationViewStyle(.stack)
        .refreshable { await store.fetch() }
    }

    private var homeworkList: some View {
        List {
            if filtered.isEmpty {
                Text(filter == .done ? "Nothing completed yet." : "You're all caught up! 🎉")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { item in
                    HomeworkRow(item: item)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Shared Homework Row

struct HomeworkRow: View {
    @EnvironmentObject private var store: PlannerStore
    let item: CanvasPlannerItem

    private var period: Period? { store.period(for: item.courseId) }
    private var urg:    Urgency { urgency(for: item.dueDate) }

    var body: some View {
        HStack(spacing: 0) {
            // Period colour bar
            Rectangle()
                .fill(period?.color ?? Color(.systemGray4))
                .frame(width: 4)
                .cornerRadius(2)
                .padding(.vertical, 4)

            HStack(spacing: 10) {
                // Complete toggle
                Button {
                    Task { await store.toggleComplete(item) }
                } label: {
                    Image(systemName: item.isComplete
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(item.isComplete ? .green : Color(.systemGray3))
                }
                .buttonStyle(.plain)

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .medium))
                        .strikethrough(item.isComplete)
                        .foregroundStyle(item.isComplete ? .secondary : .primary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if let p = period {
                            Text("P\(p.number) \(p.name)")
                                .font(.system(size: 12))
                                .foregroundStyle(p.color)
                        } else if let ctx = item.contextName {
                            Text(ctx)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Due date + urgency
                        if !item.isComplete {
                            Text(dueDateLabel(item.dueDate))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(urg.color)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(urg.color.opacity(0.12), in: Capsule())
                        } else {
                            Text(item.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dueDateLabel(_ date: Date) -> String {
        let cal  = Calendar.current
        let days = cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to:   cal.startOfDay(for: date)).day ?? 0
        if days < 0  { return "Overdue" }
        if days == 0 { return "Today"   }
        if days == 1 { return "Tomorrow" }
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
        .background(Color(.systemGroupedBackground))
    }
}
