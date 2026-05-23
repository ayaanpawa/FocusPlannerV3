#if os(macOS)
import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.openWindow) private var openWindow

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.isLoading && store.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        section(title: "Today", date: Date())
                        section(title: "Tomorrow",
                                date: cal.date(byAdding: .day, value: 1, to: Date())!)
                        upcomingSection
                    }
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 420)
            }

            Divider()
            footer
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.fpAccent)
            Text("FocusPlanner")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if let last = store.lastFetched {
                Text(last, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await store.fetch() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Refresh from Canvas")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Today / Tomorrow section

    private func section(title: String, date: Date) -> some View {
        let canvas = store.itemsOn(date)
        let custom = store.customItemsOn(date)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .kerning(0.5)
                Spacer()
                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)

            if canvas.isEmpty && custom.isEmpty {
                Text(title == "Today" ? "Nothing due — enjoy 🎉" : "Nothing yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 3) {
                    ForEach(canvas) { CanvasRow(item: $0) }
                    ForEach(custom) { CustomRow(item: $0) }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Upcoming (next 7 days, excluding today/tomorrow)

    private var upcomingSection: some View {
        let start = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: Date()))!
        let end   = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: Date()))!
        let upcoming = (store.visibleItems + [])
            .filter { $0.dueDate >= start && $0.dueDate <= end }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(5)

        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("UPCOMING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .kerning(0.5)
                        .padding(.horizontal, 12)

                    VStack(spacing: 3) {
                        ForEach(Array(upcoming)) { CanvasRow(item: $0, showDate: true) }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open App", systemImage: "rectangle.expand.vertical")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)

            Spacer()

            Button {
                NSApp.sendAction(#selector(NSApplication.terminate(_:)), to: nil, from: nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Row components

private struct CanvasRow: View {
    @EnvironmentObject private var store: PlannerStore
    let item:     CanvasPlannerItem
    var showDate: Bool = false

    private var period: Period? { store.period(for: item.courseId) }
    private var tint:   Color   { period?.color ?? (item.isCalendarEvent ? .fpAccent : .fpGreen) }

    var body: some View {
        HStack(spacing: 8) {
            if item.isAssignment {
                Button {
                    Task { await store.toggleComplete(item) }
                } label: {
                    Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(item.isComplete ? .green : .secondary)
                }
                .buttonStyle(.borderless)
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(tint)
                    .frame(width: 13)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .strikethrough(item.isComplete)
                    .foregroundStyle(item.isComplete ? .secondary : .primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let p = period {
                        Text("P\(p.number) \(p.name)")
                            .font(.system(size: 10))
                            .foregroundStyle(p.color)
                            .lineLimit(1)
                    }
                    if showDate {
                        Text("· \(item.dueDate.formatted(.dateTime.weekday(.abbreviated).day()))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

private struct CustomRow: View {
    @EnvironmentObject private var store: PlannerStore
    let item: CustomItem

    private var period: Period? { store.period(forID: item.periodId) }
    private var tint:   Color   { period?.color ?? (item.kind == .test ? .orange : .green) }

    var body: some View {
        HStack(spacing: 8) {
            if item.kind == .homework {
                Button {
                    store.toggleCustomComplete(item)
                } label: {
                    Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(item.isComplete ? .green : .secondary)
                }
                .buttonStyle(.borderless)
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(tint)
                    .frame(width: 13)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .strikethrough(item.isComplete)
                    .foregroundStyle(item.isComplete ? .secondary : .primary)
                    .lineLimit(1)
                if let p = period {
                    Text("P\(p.number) \(p.name)")
                        .font(.system(size: 10))
                        .foregroundStyle(p.color)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}
#endif
