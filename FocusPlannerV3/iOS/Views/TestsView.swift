import SwiftUI

struct TestsView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var showAdd          = false
    @State private var editingCustom: CustomItem? = nil
    @State private var detailItem: CanvasPlannerItem? = nil

    private var mergedTests: [PlannerEntry] { store.mergedUpcomingTests() }
    private var nothingToShow: Bool { mergedTests.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && nothingToShow {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if nothingToShow {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.green.opacity(0.6))
                        Text("No upcoming tests")
                            .font(.headline)
                        Text("Enjoy the break!")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.fpBg)
                } else {
                    testList
                }
            }
            .navigationTitle("Tests & Quizzes")
            .toolbar {
                ToolbarItem(placement: .barLeading) {
                    Button {
                        Task { await store.fetch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .barTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddItemSheet(kind: .test, date: Date())
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
        .stackNavStyle()
        .refreshable { await store.fetch() }
    }

    private var testList: some View {
        List {
            ForEach(mergedTests) { entry in
                Group {
                    switch entry {
                    case .canvas(let item):
                        TestRow(item: item, compact: false)
                            .contentShape(Rectangle())
                            .onTapGesture { detailItem = item }
                    case .custom(let item):
                        CustomTestRow(item: item) { editingCustom = item }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.deleteCustomItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.fpBg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared Test Row

struct TestRow: View {
    @EnvironmentObject private var store: PlannerStore
    let item:    CanvasPlannerItem
    let compact: Bool

    private var period: Period? { store.period(for: item.courseId) }
    private var type:   String  { testType(for: item.title) }
    private var days:   Int {
        let cal = Calendar.current
        return cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to:   cal.startOfDay(for: item.dueDate)).day ?? 0
    }
    private var typeColor: Color {
        switch type {
        case "Quiz":    return .fpMustard
        case "Test":    return .fpAccent
        case "Exam":    return .fpAccent
        case "Midterm": return .fpPurple
        case "Final":   return .fpPurple
        default:        return .fpGreen
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Countdown badge
            VStack(spacing: 2) {
                Text(days == 0 ? "TODAY" : "\(max(days, 0))")
                    .font(.system(size: compact ? 16 : 20, weight: .black, design: .rounded))
                    .foregroundStyle(days <= 1 ? .red : .primary)
                if days > 0 {
                    Text(days == 1 ? "day" : "days")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: compact ? 36 : 44)

            // Colour bar
            Rectangle()
                .fill(period?.color ?? Color(.systemGray4))
                .frame(width: 3)
                .cornerRadius(1.5)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: compact ? 14 : 15, weight: .semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // Class pill
                    if let p = period {
                        Text("P\(p.number) \(p.name)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(p.color)
                    } else if let ctx = item.contextName {
                        Text(ctx)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Type badge
                    Text(type)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(typeColor, in: Capsule())

                    // Date
                    Text(item.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(compact ? 10 : 14)
        .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Custom test row

struct CustomTestRow: View {
    @EnvironmentObject private var store: PlannerStore
    let item:   CustomItem
    let onEdit: () -> Void

    private var period: Period? { store.period(forID: item.periodId) }
    private var days:   Int {
        let cal = Calendar.current
        return cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to:   cal.startOfDay(for: item.dueDate)).day ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(days == 0 ? "TODAY" : "\(max(days, 0))")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(days <= 1 ? .red : .primary)
                if days > 0 {
                    Text(days == 1 ? "day" : "days")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44)

            Rectangle()
                .fill(period?.color ?? Color(.systemGray4))
                .frame(width: 3)
                .cornerRadius(1.5)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let p = period {
                        Text("P\(p.number) \(p.name)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(p.color)
                    } else {
                        Text("Added by you")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.testSubtype.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(item.testSubtype.color, in: Capsule())
                    Text(item.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}
