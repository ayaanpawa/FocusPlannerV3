import Foundation

/// User-configurable, non-secret app preferences. Stored in UserDefaults.
enum AppSettings {
    private static let schoolHostKey = "fp_schoolHost"
    private static let onboardedKey  = "fp_hasOnboarded"

    /// Canvas host like "yourschool.instructure.com" (no scheme, no path).
    static var schoolHost: String {
        get { UserDefaults.standard.string(forKey: schoolHostKey) ?? "" }
        set { UserDefaults.standard.set(normalize(newValue), forKey: schoolHostKey) }
    }

    static var hasOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: onboardedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardedKey) }
    }

    static var isConfigured: Bool {
        !schoolHost.isEmpty && (KeychainHelper.loadToken()?.isEmpty == false)
    }

    /// Strips scheme/slashes/whitespace from whatever the user pasted.
    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = s.range(of: "://") { s.removeSubrange(s.startIndex..<range.upperBound) }
        if s.hasSuffix("/") { s.removeLast() }
        return s.lowercased()
    }

    /// Sign out — wipes everything user-specific (token + cache + onboarding flag).
    static func signOut() {
        KeychainHelper.deleteToken()
        UserDefaults.standard.removeObject(forKey: schoolHostKey)
        UserDefaults.standard.removeObject(forKey: onboardedKey)
        UserDefaults.standard.removeObject(forKey: "fp_cachedItems_v2")
        UserDefaults.standard.removeObject(forKey: "fp_periods_v2")
    }
}
