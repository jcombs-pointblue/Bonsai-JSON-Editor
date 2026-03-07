import Foundation

/// Utility for formatting and parsing JSON key paths
enum KeyPathTracker {
    /// Format a path as a jq-compatible string like ".users[0].address.city"
    static func format(_ path: [JSONPathComponent]) -> String {
        if path.isEmpty { return "." }
        var result = ""
        for component in path {
            switch component {
            case .key(let k):
                // Use dot notation for simple identifiers, bracket notation for others
                if isSimpleIdentifier(k) {
                    result += ".\(k)"
                } else {
                    result += ".[\".\(k)\"]"
                }
            case .index(let i):
                result += "[\(i)]"
            }
        }
        return result
    }

    /// Check if a string is a simple identifier (letters, digits, underscores, starts with letter)
    private static func isSimpleIdentifier(_ s: String) -> Bool {
        guard let first = s.first, first.isLetter || first == "_" else { return false }
        return s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
