import Foundation

enum InviteCode {
    static let baseURL = "https://last-night-app.com/join"

    /// Build a shareable link from a raw invite code.
    static func link(for code: String) -> String {
        "\(baseURL)/\(code.uppercased())"
    }

    /// Extract an invite code from arbitrary user input — accepts either a
    /// raw code ("2E27D3") or a pasted link ("https://last-night-app.com/join/2E27D3").
    /// Returns the uppercased code, or nil if nothing usable is found.
    static func parse(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If it looks like a URL with /join/, pull the last path segment.
        if trimmed.lowercased().contains("/join/"),
           let range = trimmed.range(of: "/join/", options: .caseInsensitive) {
            let after = trimmed[range.upperBound...]
            let code = after.split(separator: "/").first.map(String.init) ?? String(after)
            let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned.uppercased()
        }

        // Otherwise treat the whole thing as a raw code.
        return trimmed.uppercased()
    }
}
