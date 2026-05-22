import Foundation

/// A unified wrapper around `CanvasPlannerItem` and `CustomItem` so they
/// can be merged into a single date-sorted list for the UI.
enum PlannerEntry: Identifiable {
    case canvas(CanvasPlannerItem)
    case custom(CustomItem)

    var id: String {
        switch self {
        case .canvas(let i): return "c_\(i.id)"
        case .custom(let i): return "u_\(i.id.uuidString)"
        }
    }

    var dueDate: Date {
        switch self {
        case .canvas(let i): return i.dueDate
        case .custom(let i): return i.dueDate
        }
    }

    var isComplete: Bool {
        switch self {
        case .canvas(let i): return i.isComplete
        case .custom(let i): return i.isComplete
        }
    }

    var isHomework: Bool {
        switch self {
        case .canvas(let i): return i.isAssignment
        case .custom(let i): return i.kind == .homework
        }
    }

    var isTest: Bool {
        switch self {
        case .canvas(let i): return i.isCalendarEvent
        case .custom(let i): return i.kind == .test
        }
    }
}
