import Foundation

/// A JSON path component for navigating the tree
enum JSONPathComponent: Hashable, Codable {
    case key(String)
    case index(Int)

    var displayString: String {
        switch self {
        case .key(let k): return ".\(k)"
        case .index(let i): return "[\(i)]"
        }
    }
}

/// A unique identifier for tree nodes, based on their path
struct NodeID: Hashable {
    let path: [JSONPathComponent]

    static let root = NodeID(path: [])

    func appending(_ component: JSONPathComponent) -> NodeID {
        NodeID(path: path + [component])
    }
}

/// Core recursive value-type representing a JSON value.
/// Objects preserve key insertion order via `orderedKeys`.
indirect enum JSONNode: Equatable, Sendable {
    case object([String: JSONNode], orderedKeys: [String])
    case array([JSONNode])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    // MARK: - Convenience accessors

    var typeName: String {
        switch self {
        case .object: return "Object"
        case .array: return "Array"
        case .string: return "String"
        case .number: return "Number"
        case .bool: return "Boolean"
        case .null: return "Null"
        }
    }

    var isContainer: Bool {
        switch self {
        case .object, .array: return true
        default: return false
        }
    }

    var childCount: Int {
        switch self {
        case .object(_, let keys): return keys.count
        case .array(let items): return items.count
        default: return 0
        }
    }

    var displayValue: String {
        switch self {
        case .string(let s): return "\"\(s)\""
        case .number(let n):
            if n == n.rounded(.towardZero) && !n.isInfinite && abs(n) < 1e15 {
                return String(format: "%.0f", n)
            }
            return String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .object(_, let keys): return "{\(keys.count)}"
        case .array(let items): return "[\(items.count)]"
        }
    }

    /// Whether this node is a leaf (non-container) type
    var isLeaf: Bool { !isContainer }

    // MARK: - Subscript access

    subscript(key: String) -> JSONNode? {
        guard case .object(let dict, _) = self else { return nil }
        return dict[key]
    }

    subscript(index: Int) -> JSONNode? {
        guard case .array(let items) = self, index >= 0, index < items.count else { return nil }
        return items[index]
    }

    /// Navigate to a node at the given path
    func node(at path: [JSONPathComponent]) -> JSONNode? {
        var current: JSONNode = self
        for component in path {
            switch component {
            case .key(let k):
                guard let next = current[k] else { return nil }
                current = next
            case .index(let i):
                guard let next = current[i] else { return nil }
                current = next
            }
        }
        return current
    }

    /// Return a new JSONNode with the value at `path` replaced by `newValue`
    func replacing(at path: [JSONPathComponent], with newValue: JSONNode) -> JSONNode {
        guard let first = path.first else { return newValue }
        let rest = Array(path.dropFirst())

        switch (self, first) {
        case (.object(var dict, let keys), .key(let k)):
            if let existing = dict[k] {
                dict[k] = existing.replacing(at: rest, with: newValue)
            }
            return .object(dict, orderedKeys: keys)

        case (.array(var items), .index(let i)) where i >= 0 && i < items.count:
            items[i] = items[i].replacing(at: rest, with: newValue)
            return .array(items)

        default:
            return self
        }
    }

    // MARK: - Ordered children for tree display

    /// Returns children as (key/index label, child node, path component) triples
    var orderedChildren: [(label: String, node: JSONNode, component: JSONPathComponent)] {
        switch self {
        case .object(let dict, let keys):
            return keys.compactMap { key in
                guard let value = dict[key] else { return nil }
                return (label: key, node: value, component: .key(key))
            }
        case .array(let items):
            return items.enumerated().map { (i, node) in
                (label: "\(i)", node: node, component: .index(i))
            }
        default:
            return []
        }
    }
}

// MARK: - Codable conformance for undo state snapshotting

extension JSONNode: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, value, keys
    }

    private enum NodeType: String, Codable {
        case object, array, string, number, bool, null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .object(let dict, let keys):
            try container.encode(NodeType.object, forKey: .type)
            try container.encode(keys, forKey: .keys)
            try container.encode(dict, forKey: .value)
        case .array(let items):
            try container.encode(NodeType.array, forKey: .type)
            try container.encode(items, forKey: .value)
        case .string(let s):
            try container.encode(NodeType.string, forKey: .type)
            try container.encode(s, forKey: .value)
        case .number(let n):
            try container.encode(NodeType.number, forKey: .type)
            try container.encode(n, forKey: .value)
        case .bool(let b):
            try container.encode(NodeType.bool, forKey: .type)
            try container.encode(b, forKey: .value)
        case .null:
            try container.encode(NodeType.null, forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(NodeType.self, forKey: .type)
        switch type {
        case .object:
            let keys = try container.decode([String].self, forKey: .keys)
            let dict = try container.decode([String: JSONNode].self, forKey: .value)
            self = .object(dict, orderedKeys: keys)
        case .array:
            let items = try container.decode([JSONNode].self, forKey: .value)
            self = .array(items)
        case .string:
            let s = try container.decode(String.self, forKey: .value)
            self = .string(s)
        case .number:
            let n = try container.decode(Double.self, forKey: .value)
            self = .number(n)
        case .bool:
            let b = try container.decode(Bool.self, forKey: .value)
            self = .bool(b)
        case .null:
            self = .null
        }
    }
}

// MARK: - Pretty printing

extension JSONNode {
    /// Format this node as a pretty-printed JSON string
    func prettyPrinted(indent: Int = 2) -> String {
        return formatNode(self, currentIndent: 0, indentSize: indent)
    }

    /// Format this node as minified JSON
    func minified() -> String {
        return formatNodeMinified(self)
    }

    private func formatNode(_ node: JSONNode, currentIndent: Int, indentSize: Int) -> String {
        let indentStr = String(repeating: " ", count: currentIndent)
        let childIndentStr = String(repeating: " ", count: currentIndent + indentSize)

        switch node {
        case .object(let dict, let keys):
            if keys.isEmpty { return "{}" }
            var lines: [String] = ["{"]
            for (i, key) in keys.enumerated() {
                guard let value = dict[key] else { continue }
                let valueStr = formatNode(value, currentIndent: currentIndent + indentSize, indentSize: indentSize)
                let comma = i < keys.count - 1 ? "," : ""
                lines.append("\(childIndentStr)\(escapeJSONString(key)): \(valueStr)\(comma)")
            }
            lines.append("\(indentStr)}")
            return lines.joined(separator: "\n")

        case .array(let items):
            if items.isEmpty { return "[]" }
            var lines: [String] = ["["]
            for (i, item) in items.enumerated() {
                let valueStr = formatNode(item, currentIndent: currentIndent + indentSize, indentSize: indentSize)
                let comma = i < items.count - 1 ? "," : ""
                lines.append("\(childIndentStr)\(valueStr)\(comma)")
            }
            lines.append("\(indentStr)]")
            return lines.joined(separator: "\n")

        case .string(let s):
            return escapeJSONString(s)

        case .number(let n):
            if n == n.rounded(.towardZero) && !n.isInfinite && abs(n) < 1e15 {
                return String(format: "%.0f", n)
            }
            return String(n)

        case .bool(let b):
            return b ? "true" : "false"

        case .null:
            return "null"
        }
    }

    private func formatNodeMinified(_ node: JSONNode) -> String {
        switch node {
        case .object(let dict, let keys):
            let pairs = keys.compactMap { key -> String? in
                guard let value = dict[key] else { return nil }
                return "\(escapeJSONString(key)):\(formatNodeMinified(value))"
            }
            return "{\(pairs.joined(separator: ","))}"

        case .array(let items):
            let elements = items.map { formatNodeMinified($0) }
            return "[\(elements.joined(separator: ","))]"

        case .string(let s):
            return escapeJSONString(s)

        case .number(let n):
            if n == n.rounded(.towardZero) && !n.isInfinite && abs(n) < 1e15 {
                return String(format: "%.0f", n)
            }
            return String(n)

        case .bool(let b):
            return b ? "true" : "false"

        case .null:
            return "null"
        }
    }

    private func escapeJSONString(_ s: String) -> String {
        var result = "\""
        for ch in s {
            switch ch {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if ch.asciiValue == nil, let scalar = ch.unicodeScalars.first, scalar.value < 0x20 {
                    let code = scalar.value
                    result += String(format: "\\u%04x", code)
                } else {
                    result.append(ch)
                }
            }
        }
        result += "\""
        return result
    }
}
