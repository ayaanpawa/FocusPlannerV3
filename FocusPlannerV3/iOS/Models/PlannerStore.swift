import Foundation
import SwiftUI
import Combine

@MainActor
final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()

    @Published var items:        [CanvasPlannerItem] = []
    @Published var periods:      [Period]            = []
    @Published var customItems:  [CustomItem]        = []
    @Published var isLoading:    Bool                = false
    @Published var errorMsg:     String?             = nil
    @Published var lastFetched:  Date?               = nil
    @Published var selectedDate: Date                = Date()
    @Published var activeTab:    Int                 = 0

    /// Personal notes the user writes on Canvas items, keyed by item id.
    @Published var itemNotes:    [String: String]    = [:]
    /// Cached full descriptions fetched from Canvas, keyed by item id.
    @Published var itemDescriptions: [String: String] = [:]

    private let cacheKey       = "fp_cachedItems_v2"
    private let periodsKey     = "fp_periods_v2"
    private let customItemsKey = "fp_customItems_v1"
    private let notesKey       = "fp_itemNotes_v1"

    init() {
        loadPeriods()
        loadCustomItems()
        loadNotes()
        loadCache()
    }

    // MARK: - Personal notes on Canvas items

    func note(for item: CanvasPlannerItem) -> String { itemNotes[item.id] ?? "" }

    func setNote(_ text: String, for item: CanvasPlannerItem) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { itemNotes.removeValue(forKey: item.id) }
        else                { itemNotes[item.id] = trimmed }
        saveNotes()
    }

    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            itemNotes = saved
        }
    }

    private func saveNotes() {
        if let data = try? JSONEncoder().encode(itemNotes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }

    // MARK: - Canvas description (fetched on demand, cached in memory)

    func description(for item: CanvasPlannerItem) -> String? {
        // Prefer the inline description if Canvas already gave us one.
        if let inline = item.plannable.description, !inline.isEmpty {
            return CanvasService.stripHTML(inline)
        }
        return itemDescriptions[item.id]
    }

    func loadDescriptionIfNeeded(for item: CanvasPlannerItem) async {
        guard item.isAssignment,
              itemDescriptions[item.id] == nil,
              (item.plannable.description ?? "").isEmpty,
              let courseId = item.courseId,
              let token = KeychainHelper.loadToken()
        else { return }

        if let text = try? await CanvasService.shared.fetchAssignmentDescription(
            token: token, courseId: courseId, assignmentId: item.plannableId
        ), !text.isEmpty {
            itemDescriptions[item.id] = text
        }
    }

    // MARK: - Periods

    func loadPeriods() {
        if let data = UserDefaults.standard.data(forKey: periodsKey),
           let saved = try? JSONDecoder().decode([Period].self, from: data) {
            periods = saved
        } else {
            periods = Period.defaultSchedule
        }
    }

    func savePeriods() {
        if let data = try? JSONEncoder().encode(periods) {
            UserDefaults.standard.set(data, forKey: periodsKey)
        }
    }

    func period(for courseId: Int?) -> Period? {
        guard let id = courseId else { return nil }
        return periods.first { $0.courseId == id }
    }

    func period(forID id: UUID?) -> Period? {
        guard let id = id else { return nil }
        return periods.first { $0.id == id }
    }

    // MARK: - Custom items

    func addCustomItem(_ item: CustomItem) {
        customItems.append(item)
        saveCustomItems()
    }

    func updateCustomItem(_ item: CustomItem) {
        if let idx = customItems.firstIndex(where: { $0.id == item.id }) {
            customItems[idx] = item
            saveCustomItems()
        }
    }

    func deleteCustomItem(_ item: CustomItem) {
        customItems.removeAll { $0.id == item.id }
        saveCustomItems()
    }

    func toggleCustomComplete(_ item: CustomItem) {
        if let idx = customItems.firstIndex(where: { $0.id == item.id }) {
            customItems[idx].isComplete.toggle()
            saveCustomItems()
        }
    }

    func customHomework() -> [CustomItem] {
        customItems
            .filter { $0.kind == .homework }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func customTests() -> [CustomItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return customItems
            .filter { $0.kind == .test && $0.dueDate >= today }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func customItemsOn(_ date: Date) -> [CustomItem] {
        customItems
            .filter { Calendar.current.isDate($0.dueDate, inSameDayAs: date) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Merged accessors (Canvas + custom, sorted together by due date)

    func mergedHomework() -> [PlannerEntry] {
        let canvas = homeworkItems.map(PlannerEntry.canvas)
        let custom = customHomework().map(PlannerEntry.custom)
        return (canvas + custom).sorted { $0.dueDate < $1.dueDate }
    }

    func mergedUpcomingTests() -> [PlannerEntry] {
        let canvas = upcomingTestItems.map(PlannerEntry.canvas)
        let custom = customTests().map(PlannerEntry.custom)
        return (canvas + custom).sorted { $0.dueDate < $1.dueDate }
    }

    func mergedItemsOn(_ date: Date) -> [PlannerEntry] {
        let canvas = itemsOn(date).map(PlannerEntry.canvas)
        let custom = customItemsOn(date).map(PlannerEntry.custom)
        return (canvas + custom).sorted { $0.dueDate < $1.dueDate }
    }

    private func saveCustomItems() {
        if let data = try? JSONEncoder().encode(customItems) {
            UserDefaults.standard.set(data, forKey: customItemsKey)
        }
    }

    private func loadCustomItems() {
        guard let data = UserDefaults.standard.data(forKey: customItemsKey),
              let decoded = try? JSONDecoder().decode([CustomItem].self, from: data)
        else { return }
        customItems = decoded
    }

    // MARK: - Canvas course sync

    private static let autoPalette: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#32ADE6", "#007AFF", "#BF5AF2",
        "#FF2D55", "#8E8E93"
    ]

    /// Add Periods for any Canvas courses we don't already have, by `courseId`.
    /// Existing entries (whether auto-imported or user-edited) are left untouched.
    func syncClasses(from courses: [CanvasCourse]) {
        let existingIDs = Set(periods.compactMap { $0.courseId })
        var used        = Set(periods.map(\.number))
        var paletteIdx  = periods.count

        for course in courses where !existingIDs.contains(course.id) {
            // Smallest unused period number, so deletions don't leave gaps
            var num = 1
            while used.contains(num) { num += 1 }
            used.insert(num)

            let hex = Self.autoPalette[paletteIdx % Self.autoPalette.count]
            periods.append(
                Period(
                    number:   num,
                    name:     course.displayName,
                    teacher:  "",
                    colorHex: hex,
                    courseId: course.id
                )
            )
            paletteIdx += 1
        }
        savePeriods()
    }

    /// Manually re-pull courses from Canvas (called from the Classes tab).
    func resyncClasses() async {
        guard let token = KeychainHelper.loadToken(),
              !token.trimmingCharacters(in: .whitespaces).isEmpty
        else { return }
        if let courses = try? await CanvasService.shared.fetchCourses(token: token) {
            syncClasses(from: courses)
        }
    }

    // MARK: - Derived item collections

    var visibleItems: [CanvasPlannerItem] {
        items.filter { !$0.isExcluded }
    }

    var homeworkItems: [CanvasPlannerItem] {
        visibleItems
            .filter { $0.isAssignment }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var upcomingTestItems: [CanvasPlannerItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return visibleItems
            .filter { $0.isCalendarEvent && $0.dueDate >= today }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func itemsOn(_ date: Date) -> [CanvasPlannerItem] {
        visibleItems.filter {
            Calendar.current.isDate($0.dueDate, inSameDayAs: date)
        }.sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Fetch

    func fetchIfNeeded() async {
        if let last = lastFetched, Date().timeIntervalSince(last) < 900 { return }
        await fetch()
    }

    func fetch() async {
        guard let token = KeychainHelper.loadToken(), !token.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMsg = CanvasError.noToken.errorDescription
            return
        }

        isLoading = items.isEmpty
        errorMsg  = nil

        let cal   = Calendar.current
        let now   = Date()
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let end   = cal.date(byAdding: .month, value: 2, to: start)!

        do {
            let fetched = try await CanvasService.shared.fetchPlannerItems(
                token: token, start: start, end: end
            )
            items       = fetched
            lastFetched = Date()
            saveCache()

            // Pull enrolled courses too — auto-add any new ones to Classes list
            if let courses = try? await CanvasService.shared.fetchCourses(token: token) {
                syncClasses(from: courses)
            }
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Toggle complete (optimistic)

    func toggleComplete(_ item: CanvasPlannerItem) async {
        guard let token = KeychainHelper.loadToken() else { return }
        let newState    = !item.isComplete
        let compositeID = item.id

        // Optimistic
        if let idx = items.firstIndex(where: { $0.id == compositeID }) {
            if items[idx].plannerOverride != nil {
                items[idx].plannerOverride!.markedComplete = newState
            } else {
                items[idx].plannerOverride = PlannerOverride(
                    id: nil,
                    plannableType:  item.plannableType,
                    plannableId:    item.plannableId,
                    markedComplete: newState,
                    dismissed:      nil
                )
            }
        }

        do {
            let result = try await CanvasService.shared.markComplete(
                token: token, item: item, complete: newState
            )
            if let idx = items.firstIndex(where: { $0.id == compositeID }) {
                items[idx].plannerOverride = result
            }
        } catch {
            // Revert
            if let idx = items.firstIndex(where: { $0.id == compositeID }) {
                items[idx].plannerOverride?.markedComplete = !newState
            }
        }
    }

    // MARK: - Cache

    private func saveCache() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([CanvasPlannerItem].self, from: data)
        else { return }
        items = cached
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        items       = []
        lastFetched = nil
    }
}
