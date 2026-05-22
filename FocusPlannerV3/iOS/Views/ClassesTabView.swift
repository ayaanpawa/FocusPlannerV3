import SwiftUI

struct ClassesTabView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var editingPeriod: Period? = nil
    @State private var showAdd       = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.periods.sorted { $0.number < $1.number }) { p in
                    PeriodRow(period: p, dueSoon: dueSoon(for: p))
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onTapGesture { editingPeriod = p }
                }

                if store.periods.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("No courses yet")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Tap + to add one.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.fpBg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Courses")
            .toolbar {
                ToolbarItem(placement: .barLeading) {
                    Button {
                        Task { await store.resyncClasses() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                ToolbarItem(placement: .barTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await store.resyncClasses() }
            .sheet(item: $editingPeriod) { period in
                PeriodEditSheet(period: period, onSave: save, onDelete: delete)
            }
            .sheet(isPresented: $showAdd) {
                PeriodEditSheet(period: newPeriod(), isNew: true, onSave: save, onDelete: nil)
            }
        }
        .stackNavStyle()
    }

    // MARK: - Helpers

    private func newPeriod() -> Period {
        let nextNum = (store.periods.map(\.number).max() ?? 0) + 1
        return Period(number: nextNum, name: "", teacher: "",
                      colorHex: "#007AFF", courseId: nil)
    }

    private func save(_ p: Period) {
        if let idx = store.periods.firstIndex(where: { $0.id == p.id }) {
            store.periods[idx] = p
        } else {
            store.periods.append(p)
        }
        store.savePeriods()
    }

    private func delete(_ p: Period) {
        store.periods.removeAll { $0.id == p.id }
        store.savePeriods()
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
                Text(period.name.isEmpty ? "Untitled" : period.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(period.name.isEmpty ? .secondary : .primary)
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
        .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Period Edit Sheet

struct PeriodEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Period
    let isNew:    Bool
    let onSave:   (Period) -> Void
    let onDelete: ((Period) -> Void)?

    init(period: Period, isNew: Bool = false,
         onSave: @escaping (Period) -> Void,
         onDelete: ((Period) -> Void)? = nil) {
        _draft        = State(initialValue: period)
        self.isNew    = isNew
        self.onSave   = onSave
        self.onDelete = onDelete
    }

    private let swatches: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#32ADE6", "#007AFF", "#BF5AF2",
        "#FF2D55", "#8E8E93"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    HStack {
                        Text("Period").foregroundStyle(.secondary)
                        Spacer()
                        Stepper("\(draft.number)", value: $draft.number, in: 1...12)
                            .labelsHidden()
                        Text("\(draft.number)")
                            .foregroundStyle(.primary)
                            .frame(minWidth: 22)
                    }
                    HStack {
                        Text("Course name").foregroundStyle(.secondary)
                        Spacer()
                        TextField("Name", text: $draft.name)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Teacher").foregroundStyle(.secondary)
                        Spacer()
                        TextField("Optional", text: $draft.teacher)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Canvas course ID").foregroundStyle(.secondary)
                        Spacer()
                        TextField("Optional",
                                  value: $draft.courseId,
                                  format: .number.grouping(.never))
                            .numberPadKeyboard()
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
                                .overlay(Circle().strokeBorder(.white, lineWidth: isSelected ? 3 : 0))
                                .shadow(color: .black.opacity(isSelected ? 0.25 : 0), radius: 4)
                                .onTapGesture { draft.colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }

                if let onDelete = onDelete, !isNew {
                    Section {
                        Button(role: .destructive) {
                            onDelete(draft)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Course")
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Course" : "Edit Period \(draft.number)")
            .navBarInline()
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
