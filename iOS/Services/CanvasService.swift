import Foundation

actor CanvasService {
    static let shared = CanvasService()

    private let base = "https://halfhollowhills.instructure.com/api/v1"

    // Decoder for live Canvas API responses (snake_case + ISO 8601 dates)
    private let liveDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: s) { return date }
            f.formatOptions = [.withInternetDateTime]
            if let date = f.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: c,
                debugDescription: "Cannot parse date: \(s)")
        }
        return d
    }()

    // MARK: - Fetch planner items (with pagination)

    func fetchPlannerItems(token: String, start: Date, end: Date) async throws -> [CanvasPlannerItem] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone   = TimeZone(identifier: "UTC")
        let startStr = fmt.string(from: start)
        let endStr   = fmt.string(from: end)

        var all: [CanvasPlannerItem] = []
        var nextURL: String? =
            "\(base)/planner/items?start_date=\(startStr)&end_date=\(endStr)&per_page=100"

        while let urlStr = nextURL {
            guard let url = URL(string: urlStr) else { break }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json+canvas-string-ids", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw CanvasError.invalidResponse }
            guard http.statusCode == 200 else { throw CanvasError.http(http.statusCode) }

            let page = try liveDecoder.decode([CanvasPlannerItem].self, from: data)
            all.append(contentsOf: page)
            nextURL = Self.parseNextLink(from: http)
        }
        return all
    }

    // MARK: - Mark complete / incomplete

    func markComplete(token: String, item: CanvasPlannerItem, complete: Bool) async throws -> PlannerOverride {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        if let override = item.plannerOverride, let oid = override.id {
            // Update existing override
            let url = URL(string: "\(base)/planner/overrides/\(oid)")!
            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(OverrideUpdate(markedComplete: complete))
            let (data, _) = try await URLSession.shared.data(for: req)
            return try liveDecoder.decode(PlannerOverride.self, from: data)
        } else {
            // Create new override
            let url = URL(string: "\(base)/planner/overrides")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(OverrideCreate(
                plannableType: item.plannableType,
                plannableId:   item.plannableId,
                markedComplete: complete
            ))
            let (data, _) = try await URLSession.shared.data(for: req)
            return try liveDecoder.decode(PlannerOverride.self, from: data)
        }
    }

    // MARK: - Helpers

    private static func parseNextLink(from response: HTTPURLResponse) -> String? {
        guard let link = response.value(forHTTPHeaderField: "Link") else { return nil }
        for part in link.components(separatedBy: ",") {
            let pieces = part.components(separatedBy: ";")
            guard pieces.count >= 2 else { continue }
            let rel = pieces[1].trimmingCharacters(in: .whitespaces)
            guard rel == "rel=\"next\"" else { continue }
            let raw = pieces[0].trimmingCharacters(in: .whitespaces)
            return String(raw.dropFirst().dropLast()) // strip < >
        }
        return nil
    }

    // Request body helpers
    private struct OverrideUpdate: Encodable { let markedComplete: Bool }
    private struct OverrideCreate: Encodable {
        let plannableType: String
        let plannableId:   Int
        let markedComplete: Bool
    }
}

// MARK: - Errors

enum CanvasError: LocalizedError {
    case noToken
    case invalidResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .noToken:         return "No API token. Open Settings and paste your Canvas token."
        case .invalidResponse: return "Unexpected response from Canvas."
        case .http(let code):  return "Canvas returned HTTP \(code). Check your token."
        }
    }
}
