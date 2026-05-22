import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss

    let item: CanvasPlannerItem

    @State private var noteText  = ""
    @State private var loadingDesc = false

    private var period: Period? { store.period(for: item.courseId) }

    private var dueText: String {
        let cal  = Calendar.current
        let days = cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to:   cal.startOfDay(for: item.dueDate)).day ?? 0
        let full = item.dueDate.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute())
        if days < 0  { return "Overdue · \(full)" }
        if days == 0 { return "Due today · \(item.dueDate.formatted(date: .omitted, time: .shortened))" }
        if days == 1 { return "Tomorrow · \(item.dueDate.formatted(date: .omitted, time: .shortened))" }
        return full
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerBlock
                    Divider().background(Color.fpDivider)
                    descriptionBlock
                    Divider().background(Color.fpDivider)
                    notesBlock
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.fpBg)
            .navBarInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.setNote(noteText, for: item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { noteText = store.note(for: item) }
            .task {
                loadingDesc = true
                await store.loadDescriptionIfNeeded(for: item)
                loadingDesc = false
            }
        }
        #if os(macOS)
        .frame(width: 560, height: 620)
        #endif
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(period?.color ?? Color.fpInkMuted)
                    .frame(width: 4, height: 44)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.fpHeadline(22))
                        .foregroundStyle(Color.fpInk)
                    if let p = period {
                        Text("P\(p.number) · \(p.name)")
                            .font(.fpMono(12))
                            .foregroundStyle(Color.fpInkMuted)
                    } else if let ctx = item.contextName {
                        Text(ctx)
                            .font(.fpMono(12))
                            .foregroundStyle(Color.fpInkMuted)
                    }
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Label(dueText, systemImage: "clock")
                    .font(.fpMono(12))
                    .foregroundStyle(Color.fpInkMuted)
            }

            if item.isAssignment {
                Button {
                    Task { await store.toggleComplete(item) }
                } label: {
                    Label(item.isComplete ? "Completed" : "Mark complete",
                          systemImage: item.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.fpBody(13, weight: .semibold))
                        .foregroundStyle(item.isComplete ? Color.fpBg : Color.fpInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(item.isComplete ? Color.fpGreen : Color.fpBgRaised,
                                    in: Capsule())
                        .overlay(
                            Capsule().strokeBorder(
                                item.isComplete ? Color.clear : Color.fpDivider, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Canvas description

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DESCRIPTION")
                .font(.fpMono(10, weight: .bold))
                .foregroundStyle(Color.fpInkSubtle)
                .kerning(0.6)

            if let desc = store.description(for: item), !desc.isEmpty {
                Text(desc)
                    .font(.fpBody(14, weight: .regular))
                    .foregroundStyle(Color.fpInk)
                    .textSelection(.enabled)
            } else if loadingDesc {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading from Canvas…")
                        .font(.fpMono(12))
                        .foregroundStyle(Color.fpInkSubtle)
                }
            } else {
                Text("No description provided.")
                    .font(.fpMono(12))
                    .foregroundStyle(Color.fpInkSubtle)
            }
        }
    }

    // MARK: - Personal notes

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MY NOTES")
                .font(.fpMono(10, weight: .bold))
                .foregroundStyle(Color.fpInkSubtle)
                .kerning(0.6)

            TextEditor(text: $noteText)
                .font(.fpBody(14, weight: .regular))
                .foregroundStyle(Color.fpInk)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120, alignment: .topLeading)
                .padding(10)
                .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.fpDivider, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if noteText.isEmpty {
                        Text("Add your own notes, reminders, or to-dos…")
                            .font(.fpBody(14, weight: .regular))
                            .foregroundStyle(Color.fpInkSubtle)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
