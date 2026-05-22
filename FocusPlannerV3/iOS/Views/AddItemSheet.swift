import SwiftUI

struct AddItemSheet: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CustomItem
    let isNew: Bool

    init(kind: CustomItemKind, date: Date) {
        _draft = State(initialValue: CustomItem(title: "", kind: kind, dueDate: date))
        isNew = true
    }

    init(editing item: CustomItem) {
        _draft = State(initialValue: item)
        isNew = false
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    titleField
                    typeField
                    dueField
                    courseField
                    notesField
                    if !isNew { deleteButton }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.fpBg)
            .navigationTitle(isNew ? "New \(draft.kind.label)" : "Edit \(draft.kind.label)")
            .navBarInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        #if os(macOS)
        .frame(width: 440, height: 560)
        #endif
    }

    // MARK: - Fields

    private var titleField: some View {
        fieldLabel("Title") {
            TextField(draft.kind == .test ? "e.g. Unit 5 Test" : "e.g. Chapter 8 Problems",
                      text: $draft.title)
                .textFieldStyle(.plain)
                .font(.fpBody(15, weight: .regular))
                .foregroundStyle(Color.fpInk)
                .padding(12)
                .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.fpDivider, lineWidth: 1)
                )
        }
    }

    private var typeField: some View {
        fieldLabel("Type") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Kind", selection: $draft.kind) {
                    Text("Homework").tag(CustomItemKind.homework)
                    Text("Test / Quiz").tag(CustomItemKind.test)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if draft.kind == .test {
                    Picker("Test type", selection: $draft.testSubtype) {
                        ForEach(TestSubtype.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }

    private var dueField: some View {
        fieldLabel("Due date") {
            DatePicker("", selection: $draft.dueDate, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private var courseField: some View {
        fieldLabel("Course") {
            Picker("Course", selection: $draft.periodId) {
                Text("None").tag(UUID?.none)
                ForEach(store.periods.sorted { $0.number < $1.number }) { p in
                    Text("P\(p.number)  \(p.name.isEmpty ? "Untitled" : p.name)")
                        .tag(Optional(p.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Color.fpInk)
        }
    }

    private var notesField: some View {
        fieldLabel("Notes") {
            TextEditor(text: $draft.notes)
                .font(.fpBody(14, weight: .regular))
                .foregroundStyle(Color.fpInk)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90, alignment: .topLeading)
                .padding(8)
                .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.fpDivider, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if draft.notes.isEmpty {
                        Text("Optional notes…")
                            .font(.fpBody(14, weight: .regular))
                            .foregroundStyle(Color.fpInkSubtle)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            store.deleteCustomItem(draft)
            dismiss()
        } label: {
            HStack {
                Spacer()
                Label("Delete", systemImage: "trash")
                    .font(.fpBody(14, weight: .semibold))
                Spacer()
            }
            .padding(.vertical, 11)
            .background(Color.fpAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(Color.fpAccent)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func fieldLabel<Content: View>(
        _ label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(.fpMono(10, weight: .bold))
                .foregroundStyle(Color.fpInkSubtle)
                .kerning(0.6)
            content()
        }
    }

    private func save() {
        let trimmed = draft.title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        draft.title = trimmed
        if isNew { store.addCustomItem(draft) }
        else     { store.updateCustomItem(draft) }
        dismiss()
    }
}
