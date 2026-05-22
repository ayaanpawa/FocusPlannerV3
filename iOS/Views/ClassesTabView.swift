import SwiftUI

struct ClassesTabView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var editingPeriod: Period? = nil

    var body: some View {
        NavigationView {
            List {
                ForEach(store.periods.sorted { $0.number < $1.number }) { period in
                    PeriodRow(period: period, dueSoon: dueSoon(for: period))
                        .onTapGesture { editingPeriod = period }
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Classes")
            .sheet(item: $editingPeriod) { period in
                PeriodEditSheet(period: period) { updated in
                    if let idx = store.periods.firstIndex(where: { $0.id == updated.id }) {
                        store.periods[idx] = updated
                        store.savePeriods()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func dueSoon(for period: Period) -> Int {
        guard let cid = period.courseId else { return 0 }
        let cal    = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: 7, to: Date())!
        return store.homeworkItems.filter {
            $0.courseId == cid && !$0.isComplete &&
            $0.dueDate > Date() && $0.dueDate <= cutoff
        }.count
    }
}

// MARK: - Period Row

struct PeriodRow: View {
    let period:  Period
    let dueSoon: Int

    var body: some View {
        HStack(spacing: 14) {
            // Color circle with period number
            ZStack {
                Circle()
                    .fill(period.color.opacity(0.18))
                    .frame(width: 42, height: 42)
                Circle()
                    .strokeBorder(period.color.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 42, height: 42)
                Text("\(period.number)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(period.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(period.name)
                    .font(.system(size: 15, weight: .semibold))

                if !period.teacher.isEmpty {
                    Text(period.teacher)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if dueSoon > 0 {
                VStack(spacing: 2) {
                    Text("\(dueSoon)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(period.color)
                    Text("due")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(period.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Period Edit Sheet

struct PeriodEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft:  Period
    let onSave: (Period) -> Void

    init(period: Period, onSave: @escaping (Period) -> Void) {
        _draft  = State(initialValue: period)
        self.onSave = onSave
    }

    // Preset color swatches
    private let swatches: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#32ADE6", "#007AFF", "#BF5AF2",
        "#FF2D55", "#8E8E93"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    HStack {
                        Text("Period")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(draft.number)")
                            .foregroundStyle(.primary)
                    }

                    HStack {
                        Text("Class name")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("Name", text: $draft.name)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Teacher")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("Optional", text: $draft.teacher)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Color") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 5),
                        spacing: 12
                    ) {
                        ForEach(swatches, id: \.self) { hex in
                            let isSelected = draft.colorHex.uppercased() == hex.uppercased()
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: isSelected ? 3 : 0)
                                )
                                .shadow(color: .black.opacity(isSelected ? 0.25 : 0), radius: 4)
                                .onTapGesture { draft.colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Edit Period \(draft.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
