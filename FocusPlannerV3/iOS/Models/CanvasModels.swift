import Foundation
import SwiftUI

// MARK: - Canvas Planner Item

struct CanvasPlannerItem: Codable, Identifiable, Sendable {
    let plannableId: Int
    let plannableType: String   // "assignment", "calendar_event", "announcement", …
    let plannableDate: Date?
    let courseId: Int?
    let contextName: String?
    let plannable: CanvasPlannable
    var plannerOverride: PlannerOverride?

    var id: String { "\(plannableType)_\(plannableId)" }

    var title: String {
        plannable.name ?? plannable.title ?? "Untitled"
    }

    var dueDate: Date {
        plannable.dueAt ?? plannable.startAt ?? plannableDate ?? .distantFuture
    }

    var isComplete: Bool {
        plannerOverride?.markedComplete ?? false
    }

    var isExcluded: Bool {
        plannableType == "announcement" ||
        title.localizedCaseInsensitiveContains("extra help")
    }

    var isAssignment:    Bool { plannableType == "assignment" }
    var isCalendarEvent: Bool { plannableType == "calendar_event" }
}

struct CanvasPlannable: Codable, Sendable {
    let id:             Int?
    let name:           String?   // assignments use "name"
    let title:          String?   // calendar events use "title"
    let dueAt:          Date?
    let startAt:        Date?
    let endAt:          Date?
    let pointsPossible: Double?
    let allDay:         Bool?
    let description:    String?   // sometimes present in planner payload
}

/// Lightweight assignment-detail response for fetching full description on demand.
struct CanvasAssignmentDetail: Codable, Sendable {
    let id:           Int
    let description:  String?
    let pointsPossible: Double?
}

struct CanvasCourse: Codable, Sendable, Identifiable {
    let id:         Int
    let name:       String?
    let courseCode: String?
    let workflowState: String?

    var displayName: String {
        name ?? courseCode ?? "Course \(id)"
    }
}

struct PlannerOverride: Codable, Sendable {
    let id:              Int?
    let plannableType:   String
    let plannableId:     Int
    var markedComplete:  Bool
    let dismissed:       Bool?
}

// MARK: - Class

struct Period: Identifiable, Codable, Equatable {
    var id       = UUID()
    var number:   Int
    var name:     String
    var teacher:  String
    var colorHex: String
    var courseId: Int?

    var color: Color { Color(hex: colorHex) }

    var label: String {
        teacher.isEmpty ? name : "\(name) (\(teacher))"
    }

    // Tolerant decoder so old saved data (with extra `day` key) still loads
    enum CodingKeys: String, CodingKey {
        case id, number, name, teacher, colorHex, courseId
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decodeIfPresent(UUID.self,  forKey: .id) ?? UUID()
        number   = try c.decode(Int.self,            forKey: .number)
        name     = try c.decode(String.self,         forKey: .name)
        teacher  = try c.decode(String.self,         forKey: .teacher)
        colorHex = try c.decode(String.self,         forKey: .colorHex)
        courseId = try c.decodeIfPresent(Int.self,   forKey: .courseId)
    }
    init(id: UUID = UUID(), number: Int, name: String, teacher: String,
         colorHex: String, courseId: Int? = nil) {
        self.id = id; self.number = number; self.name = name
        self.teacher = teacher; self.colorHex = colorHex
        self.courseId = courseId
    }
}

extension Period {
    static let defaultSchedule: [Period] = []   // classes are auto-loaded from Canvas
}

// MARK: - Urgency

enum Urgency {
    case overdue, today, soon, later

    var color: Color {
        switch self {
        case .overdue, .today: return Color.fpAccent
        case .soon:            return Color.fpMustard
        case .later:           return Color.fpInkMuted
        }
    }

    var label: String {
        switch self {
        case .overdue: return "Overdue"
        case .today:   return "Today"
        case .soon:    return "Soon"
        case .later:   return "Later"
        }
    }
}

func urgency(for date: Date) -> Urgency {
    let cal  = Calendar.current
    let days = cal.dateComponents(
        [.day],
        from: cal.startOfDay(for: Date()),
        to:   cal.startOfDay(for: date)
    ).day ?? 0
    if days < 0  { return .overdue }
    if days == 0 { return .today   }
    if days <= 3 { return .soon    }
    return .later
}

// MARK: - Test-type detection

func testType(for title: String) -> String {
    let lower = title.lowercased()
    if lower.contains("quiz")    { return "Quiz"    }
    if lower.contains("midterm") { return "Midterm" }
    if lower.contains("final")   { return "Final"   }
    if lower.contains("exam")    { return "Exam"    }
    if lower.contains("test")    { return "Test"    }
    return "Event"
}
