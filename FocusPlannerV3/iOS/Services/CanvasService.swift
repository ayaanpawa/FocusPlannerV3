import Foundation

actor CanvasService {
    static let shared = CanvasService()

    private var base: String {
        let host = AppSettings.schoolHost
        return host.isEmpty ? "" : "https://\(host)/api/v1"
    }

    private func requireBase() throws -> String {
        let b = base
        if b.isEmpty { throw CanvasError.noSchool }
        return b
    }

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
        let base = try requireBase()
        var nextURL: String? =
            "\(base)/planner/items?start_date=\(startStr)&end_date=\(endStr)&per_page=100"

        while let urlStr = nextURL {
            guard let url = URL(string: urlStr) else { break }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw CanvasError.invalidResponse }
            if http.statusCode == 401 { throw CanvasError.unauthorized }
            guard http.statusCode == 200 else { throw CanvasError.http(http.statusCode) }

            let page: [CanvasPlannerItem]
            do {
                page = try liveDecoder.decode([CanvasPlannerItem].self, from: data)
            } catch {
                #if DEBUG
                print("🔴 Canvas decoding error: \(error)")
                if let raw = String(data: data.prefix(2000), encoding: .utf8) {
                    print("🔴 First 2KB of response:\n\(raw)")
                }
                #endif
                throw CanvasError.decoding(error.localizedDescription)
            }
            all.append(contentsOf: page)
            nextURL = Self.parseNextLink(from: http)
        }
        return all
    }

    // MARK: - Fetch enrolled courses

    func fetchCourses(token: String) async throws -> [CanvasCourse] {
        let base = try requireBase()
        var all: [CanvasCourse] = []
        var nextURL: String? = "\(base)/courses?enrollment_state=active&per_page=50"

        while let urlStr = nextURL {
            guard let url = URL(string: urlStr) else { break }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw CanvasError.invalidResponse }
            if http.statusCode == 401 { throw CanvasError.unauthorized }
            guard http.statusCode == 200 else { throw CanvasError.http(http.statusCode) }

            let page = try liveDecoder.decode([CanvasCourse].self, from: data)
            all.append(contentsOf: page)
            nextURL = Self.parseNextLink(from: http)
        }
        return all.filter { $0.workflowState == "available" || $0.workflowState == nil }
    }

    // MARK: - Fetch a single assignment's full description

    func fetchAssignmentDescription(token: String, courseId: Int, assignmentId: Int) async throws -> String? {
        let base = try requireBase()
        let url = URL(string: "\(base)/courses/\(courseId)/assignments/\(assignmentId)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw CanvasError.invalidResponse }
        if http.statusCode == 401 { throw CanvasError.unauthorized }
        guard http.statusCode == 200 else { throw CanvasError.http(http.statusCode) }

        let detail = try liveDecoder.decode(CanvasAssignmentDetail.self, from: data)
        return detail.description.map { Self.stripHTML($0) }
    }

    /// Very small HTML → plain-text converter (good enough for assignment text).
    static func stripHTML(_ html: String) -> String {
        var s = html
        // Turn common block tags into line breaks
        for tag in ["<br>", "<br/>", "<br />", "</p>", "</div>", "</li>"] {
            s = s.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        s = s.replacingOccurrences(of: "<li>", with: "• ", options: .caseInsensitive)
        // Strip remaining tags
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode a few common entities
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
                        "&quot;": "\"", "&#39;": "'", "&rsquo;": "’", "&ldquo;": "“", "&rdquo;": "”"]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        // Collapse excess whitespace
        s = s.replacingOccurrences(of: "\n[ \t]*\n[ \t]*\n+", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Mark complete / incomplete

    func markComplete(token: String, item: CanvasPlannerItem, complete: Bool) async throws -> PlannerOverride {
        let base = try requireBase()
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
    case noSchool
    case unauthorized
    case invalidResponse
    case http(Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .noToken:         return "No API token. Open Settings and paste your Canvas access token."
        case .noSchool:        return "No school URL set. Open Settings and enter your Canvas address (e.g. yourschool.instructure.com)."
        case .unauthorized:    return "Your Canvas token was rejected. It may have expired — please generate a new one and update it in Settings."
        case .invalidResponse: return "Unexpected response from Canvas."
        case .http(let code):  return "Canvas returned HTTP \(code)."
        case .decoding(let m): return "Couldn't read Canvas response: \(m)"
        }
    }
}
