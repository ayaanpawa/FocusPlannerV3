import Foundation
import SwiftUI

// MARK: - Canvas Planner Item

struct CanvasPlannerItem: Codable, Identifiable {
    let plannableId: Int
    let plannableType: String   // "assignment", "calendar_event", "announcement", …
    let plannableDate: Date
    let courseId: Int?
    let contextName: String?
    let plannable: CanvasPlannable
    var plannerOverride: PlannerOverride?

    var id: String { "\(plannableType)_\(plannableId)" }

    var title: String {
        plannable.name ?? plannable.title ?? "Untitled"
    }

    var dueDate: Date {
        plannable.dueAt ?? plannable.startAt ?? plannableDate
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

struct CanvasPlannable: Codable {
    let id: Int
    let name:           String?   // assignments use "name"
    let title:          String?   // calendar events use "title"
    let dueAt:          Date?
    let startAt:        Date?
    let endAt:          Date?
    let pointsPossible: Double?
    let allDay:         Bool?
}

struct PlannerOverride: Codable {
    let id:              Int?
    let plannableType:   String
    let plannableId:     Int
    var markedComplete:  Bool
    let dismissed:       Bool?
}

// MARK: - Period / Class Schedule

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
}

extension Period {
    static let defaultSchedule: [Period] = [
        Period(number: 1, name: "H Chemistry",      teacher: "Lyons",   colorHex: "#FF3B30", courseId: 54709),
        Period(number: 2, name: "Phys Ed",           teacher: "Haugen",  colorHex: "#FF9500", courseId: 54477),
        Period(number: 3, name: "AP Biology",        teacher: "",        colorHex: "#34C759", courseId: 54779),
        Period(number: 4, name: "AP Seminar",        teacher: "",        colorHex: "#BF5AF2", courseId: 54257),
        Period(number: 5, name: "AP World History",  teacher: "Mills",   colorHex: "#32ADE6", courseId: 54338),
        Period(number: 6, name: "Geometry",          teacher: "Finley",  colorHex: "#007AFF", courseId: 54791),
        Period(number: 7, name: "Spanish 10",        teacher: "",        colorHex: "#FF2D55", courseId: 54668),
        Period(number: 8, name: "Health",            teacher: "Argenti", colorHex: "#00C7BE", courseId: 54411),
        Period(number: 9, name: "Free / Study",      teacher: "",        colorHex: "#8E8E93", courseId: nil),
    ]
}

// MARK: - A/B Day

enum ABDay: String {
    case a = "A"
    case b = "B"

    var color: Color {
        switch self {
        case .a: return .blue
        case .b: return .orange
        }
    }
}

func abDay(for date: Date) -> ABDay? {
    let cal = Calendar.current
    let weekday = cal.component(.weekday, from: date)
    guard weekday >= 2, weekday <= 6 else { return nil } // Mon–Fri only

    var comps     = DateComponents()
    comps.year    = 2026; comps.month = 5; comps.day = 11
    let abStart   = cal.startOfDay(for: cal.date(from: comps)!)
    let target    = cal.startOfDay(for: date)
    guard target >= abStart else { return nil }

    // Count school weekdays from abStart up to (not including) target
    var count  = 0
    var cursor = abStart
    while cursor < target {
        let wd = cal.component(.weekday, from: cursor)
        if wd >= 2, wd <= 6 { count += 1 }
        cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
    }
    return count % 2 == 0 ? .a : .b
}

// MARK: - Urgency

enum Urgency {
    case overdue, today, soon, later

    var color: Color {
        switch self {
        case .overdue, .today: return Color(.systemRed)
        case .soon:            return Color(.systemOrange)
        case .later:           return Color(.systemBlue)
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
