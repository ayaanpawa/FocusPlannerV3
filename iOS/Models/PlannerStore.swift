import Foundation
import SwiftUI

@MainActor
final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()

    @Published var items:       [CanvasPlannerItem] = []
    @Published var periods:     [Period]            = []
    @Published var isLoading:   Bool                = false
    @Published var errorMsg:    String?             = nil
    @Published var lastFetched: Date?               = nil

    private let cacheKey  = "fp_cachedItems_v2"
    private let periodsKey = "fp_periods_v2"

    init() {
        loadPeriods()
        loadCache()
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
