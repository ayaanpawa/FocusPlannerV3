import Foundation
import SwiftUI

enum CustomItemKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case homework, test

    var id: String { rawValue }

    var label: String {
        switch self {
        case .homework: return "Homework"
        case .test:     return "Test"
        }
    }

    var icon: String {
        switch self {
        case .homework: return "doc.text.fill"
        case .test:     return "bolt.fill"
        }
    }
}

enum TestSubtype: String, Codable, Sendable, CaseIterable {
    case test    = "Test"
    case quiz    = "Quiz"
    case exam    = "Exam"
    case midterm = "Midterm"
    case final   = "Final"

    var color: Color {
        switch self {
        case .quiz:                       return .fpMustard
        case .test, .exam:                return .fpAccent
        case .midterm, .final:            return .fpPurple
        }
    }
}

struct CustomItem: Identifiable, Codable, Sendable, Equatable {
    var id        = UUID()
    var title:     String
    var kind:      CustomItemKind
    var dueDate:   Date
    var periodId:  UUID?        // links to a local Period
    var notes:     String       = ""
    var isComplete: Bool        = false
    var testSubtype: TestSubtype = .test    // only relevant when kind == .test
    var createdAt: Date         = Date()
}
