import SwiftUI

struct TestsView: View {
    @EnvironmentObject private var store: PlannerStore

    var body: some View {
        NavigationView {
            Group {
                if store.isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.upcomingTestItems.isEmpty {
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
                    .background(Color(.systemGroupedBackground))
                } else {
                    testList
                }
            }
            .navigationTitle("Tests & Quizzes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await store.fetch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .refreshable { await store.fetch() }
    }

    private var testList: some View {
        List {
            ForEach(store.upcomingTestItems) { item in
                TestRow(item: item, compact: false)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
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
        case "Quiz":    return .blue
        case "Test":    return .red
        case "Exam":    return .red
        case "Midterm": return .purple
        case "Final":   return .purple
        default:        return .orange
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
