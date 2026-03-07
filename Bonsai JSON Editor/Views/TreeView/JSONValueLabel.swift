import SwiftUI

/// Displays a JSON value with appropriate color coding
struct JSONValueLabel: View {
    let node: JSONNode

    var body: some View {
        switch node {
        case .string(let s):
            Text("\"\(s)\"")
                .foregroundStyle(.green)
                .lineLimit(1)

        case .number(let n):
            Text(formatNumber(n))
                .foregroundStyle(.blue)

        case .bool(let b):
            Text(b ? "true" : "false")
                .foregroundStyle(.orange)

        case .null:
            Text("null")
                .foregroundStyle(.secondary)
                .italic()

        case .object(_, let keys):
            Text("{\(keys.count)}")
                .foregroundStyle(.secondary)
                .font(.caption)

        case .array(let items):
            Text("[\(items.count)]")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private func formatNumber(_ n: Double) -> String {
        if n == n.rounded(.towardZero) && !n.isInfinite && abs(n) < 1e15 {
            return String(format: "%.0f", n)
        }
        return String(n)
    }
}
