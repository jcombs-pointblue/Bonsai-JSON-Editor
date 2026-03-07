import Foundation

/// Runtime errors thrown during jq evaluation
enum JQRuntimeError: LocalizedError {
    case typeMismatch(expected: String, got: String, context: String)
    case indexOutOfBounds(Int, count: Int)
    case undefinedField(String)
    case divisionByZero
    case invalidArgument(String)
    case iterateOnScalar
    case empty
    case customError(String)

    var errorDescription: String? {
        switch self {
        case .typeMismatch(let expected, let got, let context):
            return "\(context): expected \(expected), got \(got)"
        case .indexOutOfBounds(let idx, let count):
            return "Index \(idx) out of bounds (count: \(count))"
        case .undefinedField(let field):
            return "Undefined field: .\(field)"
        case .divisionByZero:
            return "Division by zero"
        case .invalidArgument(let msg):
            return "Invalid argument: \(msg)"
        case .iterateOnScalar:
            return "Cannot iterate over scalar value"
        case .empty:
            return "empty"
        case .customError(let msg):
            return msg
        }
    }
}

/// Evaluates jq expressions against JSON nodes.
/// The evaluator is recursive and produces a stream of results (jq is a generator-based language).
struct JQEvaluator {

    /// Evaluate a jq expression string against a JSON node
    static func evaluate(expression: String, input: JSONNode) throws -> [JSONNode] {
        let tokens = try JQLexer.tokenize(expression)
        let ast = try JQParser.parse(tokens)
        return try evaluate(ast, input: input)
    }

    /// Evaluate a parsed JQExpression against a JSON node
    static func evaluate(_ expression: JQExpression, input: JSONNode) throws -> [JSONNode] {
        do {
            return try eval(expression, input: input)
        } catch JQRuntimeError.empty {
            return []
        }
    }

    // MARK: - Core evaluation

    private static func eval(_ expr: JQExpression, input: JSONNode) throws -> [JSONNode] {
        switch expr {
        case .identity:
            return [input]

        case .recursive:
            return recurseAll(input)

        case .field(let name, let optional):
            switch input {
            case .object(let dict, _):
                if let value = dict[name] {
                    return [value]
                } else if optional {
                    return []
                } else {
                    return [.null]
                }
            case .null:
                return [.null]
            default:
                if optional { return [] }
                throw JQRuntimeError.typeMismatch(expected: "object", got: input.typeName.lowercased(), context: "field access .\(name)")
            }

        case .index(let idx):
            switch input {
            case .array(let items):
                let effectiveIdx = idx < 0 ? items.count + idx : idx
                if effectiveIdx >= 0 && effectiveIdx < items.count {
                    return [items[effectiveIdx]]
                }
                return [.null]
            case .null:
                return [.null]
            default:
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "index access")
            }

        case .slice(let start, let end):
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "slice")
            }
            let s = start ?? 0
            let e = end ?? items.count
            let effectiveStart = max(0, s < 0 ? items.count + s : s)
            let effectiveEnd = min(items.count, e < 0 ? items.count + e : e)
            if effectiveStart >= effectiveEnd {
                return [.array([])]
            }
            return [.array(Array(items[effectiveStart..<effectiveEnd]))]

        case .iterator(let optional):
            switch input {
            case .array(let items):
                return items
            case .object(let dict, let keys):
                return keys.compactMap { dict[$0] }
            case .null:
                if optional { return [] }
                throw JQRuntimeError.iterateOnScalar
            default:
                if optional { return [] }
                throw JQRuntimeError.iterateOnScalar
            }

        case .pipe(let left, let right):
            let leftResults = try eval(left, input: input)
            var allResults: [JSONNode] = []
            for result in leftResults {
                do {
                    let rightResults = try eval(right, input: result)
                    allResults.append(contentsOf: rightResults)
                } catch JQRuntimeError.empty {
                    // select() or empty — skip this output
                }
            }
            return allResults

        case .comma(let left, let right):
            var results = try eval(left, input: input)
            results.append(contentsOf: try eval(right, input: input))
            return results

        case .literal(let node):
            return [node]

        case .arrayConstruct(let inner):
            guard let inner = inner else { return [.array([])] }
            let results = try eval(inner, input: input)
            return [.array(results)]

        case .objectConstruct(let pairs):
            return try evalObjectConstruct(pairs, input: input)

        case .comparison(let left, let op, let right):
            let leftResults = try eval(left, input: input)
            let rightResults = try eval(right, input: input)
            guard let l = leftResults.first, let r = rightResults.first else {
                return []
            }
            let result = compareNodes(l, r, op: op)
            return [.bool(result)]

        case .arithmetic(let left, let op, let right):
            let leftResults = try eval(left, input: input)
            let rightResults = try eval(right, input: input)
            guard let l = leftResults.first, let r = rightResults.first else {
                return []
            }
            return [try performArithmetic(l, r, op: op)]

        case .logicalAnd(let left, let right):
            let leftResults = try eval(left, input: input)
            guard let l = leftResults.first else { return [.bool(false)] }
            if !isTruthy(l) { return [.bool(false)] }
            let rightResults = try eval(right, input: input)
            guard let r = rightResults.first else { return [.bool(false)] }
            return [.bool(isTruthy(r))]

        case .logicalOr(let left, let right):
            let leftResults = try eval(left, input: input)
            guard let l = leftResults.first else {
                let rightResults = try eval(right, input: input)
                guard let r = rightResults.first else { return [.bool(false)] }
                return [.bool(isTruthy(r))]
            }
            if isTruthy(l) { return [.bool(true)] }
            let rightResults = try eval(right, input: input)
            guard let r = rightResults.first else { return [.bool(false)] }
            return [.bool(isTruthy(r))]

        case .not(let inner):
            let results = try eval(inner, input: input)
            guard let first = results.first else { return [.bool(true)] }
            return [.bool(!isTruthy(first))]

        case .negate(let inner):
            let results = try eval(inner, input: input)
            guard let first = results.first else { return [] }
            guard case .number(let n) = first else {
                throw JQRuntimeError.typeMismatch(expected: "number", got: first.typeName.lowercased(), context: "negation")
            }
            return [.number(-n)]

        case .ifThenElse(let condition, let thenExpr, let elseExpr):
            let condResults = try eval(condition, input: input)
            guard let condValue = condResults.first else { return [] }
            if isTruthy(condValue) {
                return try eval(thenExpr, input: input)
            } else if let elseExpr = elseExpr {
                return try eval(elseExpr, input: input)
            }
            return [input]

        case .tryExpr(let inner, let catchExpr):
            do {
                return try eval(inner, input: input)
            } catch {
                if let catchExpr = catchExpr {
                    return try eval(catchExpr, input: input)
                }
                return []
            }

        case .builtin(let name, let args):
            return try evalBuiltin(name, args: args, input: input)

        case .funcCall(let name, let args):
            return try evalBuiltin(name, args: args, input: input)
        }
    }

    // MARK: - Built-in functions

    private static func evalBuiltin(_ name: String, args: [JQExpression], input: JSONNode) throws -> [JSONNode] {
        switch name {
        // Type functions
        case "length":
            return [.number(Double(nodeLength(input)))]

        case "type":
            return [.string(jqTypeName(input))]

        case "keys", "keys_unsorted":
            guard case .object(_, let orderedKeys) = input else {
                if case .array(let items) = input {
                    return [.array(items.indices.map { .number(Double($0)) })]
                }
                throw JQRuntimeError.typeMismatch(expected: "object", got: input.typeName.lowercased(), context: "keys")
            }
            let sorted = name == "keys" ? orderedKeys.sorted() : orderedKeys
            return [.array(sorted.map { .string($0) })]

        case "values":
            switch input {
            case .object(let dict, let keys):
                return [.array(keys.compactMap { dict[$0] })]
            case .array:
                return [input]
            default:
                throw JQRuntimeError.typeMismatch(expected: "object/array", got: input.typeName.lowercased(), context: "values")
            }

        case "has":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("has requires 1 argument")
            }
            let argResults = try eval(arg, input: input)
            guard let key = argResults.first else { return [.bool(false)] }
            switch (input, key) {
            case (.object(let dict, _), .string(let k)):
                return [.bool(dict[k] != nil)]
            case (.array(let items), .number(let n)):
                let idx = Int(n)
                return [.bool(idx >= 0 && idx < items.count)]
            default:
                return [.bool(false)]
            }

        case "contains":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("contains requires 1 argument")
            }
            let argResults = try eval(arg, input: input)
            guard let other = argResults.first else { return [.bool(false)] }
            return [.bool(nodeContains(input, other))]

        case "inside":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("inside requires 1 argument")
            }
            let argResults = try eval(arg, input: input)
            guard let other = argResults.first else { return [.bool(false)] }
            return [.bool(nodeContains(other, input))]

        case "select":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("select requires 1 argument")
            }
            let results = try eval(arg, input: input)
            guard let first = results.first, isTruthy(first) else {
                throw JQRuntimeError.empty
            }
            return [input]

        case "map":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("map requires 1 argument")
            }
            // map(f) is [.[] | f]
            switch input {
            case .array(let items):
                var results: [JSONNode] = []
                for item in items {
                    do {
                        results.append(contentsOf: try eval(arg, input: item))
                    } catch JQRuntimeError.empty {
                        // select() returns empty — skip this item
                    }
                }
                return [.array(results)]
            default:
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "map")
            }

        case "map_values":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("map_values requires 1 argument")
            }
            switch input {
            case .object(var dict, let keys):
                for key in keys {
                    if let val = dict[key] {
                        let results = try eval(arg, input: val)
                        if let first = results.first {
                            dict[key] = first
                        }
                    }
                }
                return [.object(dict, orderedKeys: keys)]
            case .array(let items):
                var results: [JSONNode] = []
                for item in items {
                    let res = try eval(arg, input: item)
                    if let first = res.first {
                        results.append(first)
                    }
                }
                return [.array(results)]
            default:
                throw JQRuntimeError.typeMismatch(expected: "object/array", got: input.typeName.lowercased(), context: "map_values")
            }

        case "to_entries":
            guard case .object(let dict, let keys) = input else {
                throw JQRuntimeError.typeMismatch(expected: "object", got: input.typeName.lowercased(), context: "to_entries")
            }
            let entries = keys.compactMap { key -> JSONNode? in
                guard let value = dict[key] else { return nil }
                return .object(["key": .string(key), "value": value], orderedKeys: ["key", "value"])
            }
            return [.array(entries)]

        case "from_entries":
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "from_entries")
            }
            var dict: [String: JSONNode] = [:]
            var keys: [String] = []
            for item in items {
                guard case .object(let entryDict, _) = item else { continue }
                // Support both "key"/"name" and "value"
                let key: String
                if case .string(let k) = entryDict["key"] {
                    key = k
                } else if case .string(let n) = entryDict["name"] {
                    key = n
                } else {
                    continue
                }
                let value = entryDict["value"] ?? .null
                if dict[key] == nil {
                    keys.append(key)
                }
                dict[key] = value
            }
            return [.object(dict, orderedKeys: keys)]

        case "with_entries":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("with_entries requires 1 argument")
            }
            // with_entries(f) is to_entries | map(f) | from_entries
            let entries = try eval(.builtin("to_entries", args: []), input: input)
            guard let entriesArray = entries.first else { return [.null] }
            let mapped = try eval(.builtin("map", args: [arg]), input: entriesArray)
            guard let mappedArray = mapped.first else { return [.null] }
            return try eval(.builtin("from_entries", args: []), input: mappedArray)

        case "add":
            if args.isEmpty {
                // add on array: sum/concat all elements
                guard case .array(let items) = input else {
                    throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "add")
                }
                if items.isEmpty { return [.null] }
                var result = items[0]
                for item in items.dropFirst() {
                    result = try performArithmetic(result, item, op: .add)
                }
                return [result]
            } else {
                throw JQRuntimeError.invalidArgument("add takes no arguments")
            }

        case "any":
            if let arg = args.first {
                guard case .array(let items) = input else {
                    throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "any")
                }
                for item in items {
                    let results = try eval(arg, input: item)
                    if let first = results.first, isTruthy(first) {
                        return [.bool(true)]
                    }
                }
                return [.bool(false)]
            } else {
                guard case .array(let items) = input else {
                    throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "any")
                }
                return [.bool(items.contains { isTruthy($0) })]
            }

        case "all":
            if let arg = args.first {
                guard case .array(let items) = input else {
                    throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "all")
                }
                for item in items {
                    let results = try eval(arg, input: item)
                    if let first = results.first, !isTruthy(first) {
                        return [.bool(false)]
                    }
                }
                return [.bool(true)]
            } else {
                guard case .array(let items) = input else {
                    throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "all")
                }
                return [.bool(items.allSatisfy { isTruthy($0) })]
            }

        case "flatten":
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "flatten")
            }
            let depth: Int
            if let arg = args.first {
                let results = try eval(arg, input: input)
                if case .number(let n) = results.first {
                    depth = Int(n)
                } else {
                    depth = 1
                }
            } else {
                depth = 1
            }
            return [.array(flattenArray(items, depth: depth))]

        case "reverse":
            guard case .array(let items) = input else {
                if case .string(let s) = input {
                    return [.string(String(s.reversed()))]
                }
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "reverse")
            }
            return [.array(items.reversed())]

        case "sort":
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "sort")
            }
            let sorted = items.sorted { compareNodes($0, $1, op: .lt) }
            return [.array(sorted)]

        case "sort_by":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("sort_by requires 1 argument")
            }
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "sort_by")
            }
            let sorted = try items.sorted { a, b in
                let aKey = try eval(arg, input: a).first ?? .null
                let bKey = try eval(arg, input: b).first ?? .null
                return compareNodes(aKey, bKey, op: .lt)
            }
            return [.array(sorted)]

        case "unique":
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "unique")
            }
            var seen: [JSONNode] = []
            for item in items {
                if !seen.contains(item) {
                    seen.append(item)
                }
            }
            return [.array(seen)]

        case "unique_by":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("unique_by requires 1 argument")
            }
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "unique_by")
            }
            var seenKeys: [JSONNode] = []
            var result: [JSONNode] = []
            for item in items {
                let key = try eval(arg, input: item).first ?? .null
                if !seenKeys.contains(key) {
                    seenKeys.append(key)
                    result.append(item)
                }
            }
            return [.array(result)]

        case "group_by":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("group_by requires 1 argument")
            }
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "group_by")
            }
            var groups: [(key: JSONNode, items: [JSONNode])] = []
            for item in items {
                let key = try eval(arg, input: item).first ?? .null
                if let idx = groups.firstIndex(where: { $0.key == key }) {
                    groups[idx].items.append(item)
                } else {
                    groups.append((key: key, items: [item]))
                }
            }
            return [.array(groups.map { .array($0.items) })]

        case "min":
            guard case .array(let items) = input, !items.isEmpty else {
                return [.null]
            }
            let sorted = items.sorted { compareNodes($0, $1, op: .lt) }
            return [sorted.first ?? .null]

        case "max":
            guard case .array(let items) = input, !items.isEmpty else {
                return [.null]
            }
            let sorted = items.sorted { compareNodes($0, $1, op: .lt) }
            return [sorted.last ?? .null]

        case "min_by":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("min_by requires 1 argument")
            }
            guard case .array(let items) = input, !items.isEmpty else {
                return [.null]
            }
            let minItem = try items.min { a, b in
                let aKey = try eval(arg, input: a).first ?? .null
                let bKey = try eval(arg, input: b).first ?? .null
                return compareNodes(aKey, bKey, op: .lt)
            }
            return [minItem ?? .null]

        case "max_by":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("max_by requires 1 argument")
            }
            guard case .array(let items) = input, !items.isEmpty else {
                return [.null]
            }
            let maxItem = try items.max { a, b in
                let aKey = try eval(arg, input: a).first ?? .null
                let bKey = try eval(arg, input: b).first ?? .null
                return compareNodes(aKey, bKey, op: .lt)
            }
            return [maxItem ?? .null]

        case "first":
            if let arg = args.first {
                let results = try eval(arg, input: input)
                return results.isEmpty ? [] : [results[0]]
            }
            guard case .array(let items) = input, !items.isEmpty else { return [.null] }
            return [items[0]]

        case "last":
            if let arg = args.first {
                let results = try eval(arg, input: input)
                return results.isEmpty ? [] : [results[results.count - 1]]
            }
            guard case .array(let items) = input, !items.isEmpty else { return [.null] }
            return [items[items.count - 1]]

        case "range":
            if args.count == 1 {
                let endResults = try eval(args[0], input: input)
                guard case .number(let end) = endResults.first else {
                    throw JQRuntimeError.invalidArgument("range requires numeric arguments")
                }
                return (0..<Int(end)).map { .number(Double($0)) }
            } else if args.count >= 2 {
                let startResults = try eval(args[0], input: input)
                let endResults = try eval(args[1], input: input)
                guard case .number(let start) = startResults.first,
                      case .number(let end) = endResults.first else {
                    throw JQRuntimeError.invalidArgument("range requires numeric arguments")
                }
                return (Int(start)..<Int(end)).map { .number(Double($0)) }
            }
            throw JQRuntimeError.invalidArgument("range requires 1-3 arguments")

        case "empty":
            throw JQRuntimeError.empty

        case "error":
            if let arg = args.first {
                let results = try eval(arg, input: input)
                if case .string(let msg) = results.first {
                    throw JQRuntimeError.customError(msg)
                }
            }
            throw JQRuntimeError.customError("error")

        case "not":
            return [.bool(!isTruthy(input))]

        case "tostring":
            switch input {
            case .string: return [input]
            case .number(let n):
                if n == n.rounded(.towardZero) && !n.isInfinite && abs(n) < 1e15 {
                    return [.string(String(format: "%.0f", n))]
                }
                return [.string(String(n))]
            case .bool(let b): return [.string(b ? "true" : "false")]
            case .null: return [.string("null")]
            default: return [.string(input.minified())]
            }

        case "tonumber":
            switch input {
            case .number: return [input]
            case .string(let s):
                guard let n = Double(s) else {
                    throw JQRuntimeError.invalidArgument("Cannot convert '\(s)' to number")
                }
                return [.number(n)]
            default:
                throw JQRuntimeError.typeMismatch(expected: "string/number", got: input.typeName.lowercased(), context: "tonumber")
            }

        case "ascii_downcase":
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "ascii_downcase")
            }
            return [.string(s.lowercased())]

        case "ascii_upcase":
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "ascii_upcase")
            }
            return [.string(s.uppercased())]

        case "ltrimstr":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("ltrimstr requires 1 argument")
            }
            guard case .string(let s) = input else { return [input] }
            let results = try eval(arg, input: input)
            guard case .string(let prefix) = results.first else { return [input] }
            if s.hasPrefix(prefix) {
                return [.string(String(s.dropFirst(prefix.count)))]
            }
            return [input]

        case "rtrimstr":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("rtrimstr requires 1 argument")
            }
            guard case .string(let s) = input else { return [input] }
            let results = try eval(arg, input: input)
            guard case .string(let suffix) = results.first else { return [input] }
            if s.hasSuffix(suffix) {
                return [.string(String(s.dropLast(suffix.count)))]
            }
            return [input]

        case "startswith":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("startswith requires 1 argument")
            }
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "startswith")
            }
            let results = try eval(arg, input: input)
            guard case .string(let prefix) = results.first else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: "other", context: "startswith argument")
            }
            return [.bool(s.hasPrefix(prefix))]

        case "endswith":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("endswith requires 1 argument")
            }
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "endswith")
            }
            let results = try eval(arg, input: input)
            guard case .string(let suffix) = results.first else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: "other", context: "endswith argument")
            }
            return [.bool(s.hasSuffix(suffix))]

        case "split":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("split requires 1 argument")
            }
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "split")
            }
            let results = try eval(arg, input: input)
            guard case .string(let separator) = results.first else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: "other", context: "split argument")
            }
            let parts = s.components(separatedBy: separator)
            return [.array(parts.map { .string($0) })]

        case "join":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("join requires 1 argument")
            }
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "join")
            }
            let results = try eval(arg, input: input)
            guard case .string(let separator) = results.first else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: "other", context: "join argument")
            }
            let strings = items.map { node -> String in
                switch node {
                case .string(let s): return s
                case .number(let n):
                    if n == n.rounded(.towardZero) && !n.isInfinite && abs(n) < 1e15 {
                        return String(format: "%.0f", n)
                    }
                    return String(n)
                case .bool(let b): return b ? "true" : "false"
                case .null: return ""
                default: return node.minified()
                }
            }
            return [.string(strings.joined(separator: separator))]

        case "test":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("test requires 1 argument")
            }
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "test")
            }
            let results = try eval(arg, input: input)
            guard case .string(let pattern) = results.first else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: "other", context: "test pattern")
            }
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(s.startIndex..., in: s)
            return [.bool(regex.firstMatch(in: s, range: range) != nil)]

        case "match":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("match requires 1 argument")
            }
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "match")
            }
            let results = try eval(arg, input: input)
            guard case .string(let pattern) = results.first else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: "other", context: "match pattern")
            }
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(s.startIndex..., in: s)
            guard let m = regex.firstMatch(in: s, range: range) else {
                throw JQRuntimeError.customError("match: no match found")
            }
            let matchRange = Range(m.range, in: s)!
            let matchStr = String(s[matchRange])
            let offset = s.distance(from: s.startIndex, to: matchRange.lowerBound)
            let length = matchStr.count

            var captures: [JSONNode] = []
            for i in 1..<m.numberOfRanges {
                let captureRange = m.range(at: i)
                if captureRange.location != NSNotFound, let r = Range(captureRange, in: s) {
                    captures.append(.object(
                        ["offset": .number(Double(s.distance(from: s.startIndex, to: r.lowerBound))),
                         "length": .number(Double(s[r].count)),
                         "string": .string(String(s[r])),
                         "name": .null],
                        orderedKeys: ["offset", "length", "string", "name"]
                    ))
                }
            }

            return [.object(
                ["offset": .number(Double(offset)),
                 "length": .number(Double(length)),
                 "string": .string(matchStr),
                 "captures": .array(captures)],
                orderedKeys: ["offset", "length", "string", "captures"]
            )]

        case "indices", "index", "rindex":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("\(name) requires 1 argument")
            }
            let results = try eval(arg, input: input)
            guard let searchVal = results.first else { return [.null] }

            if case .string(let s) = input, case .string(let sub) = searchVal {
                var foundIndices: [Int] = []
                var searchRange = s.startIndex..<s.endIndex
                while let range = s.range(of: sub, range: searchRange) {
                    foundIndices.append(s.distance(from: s.startIndex, to: range.lowerBound))
                    searchRange = range.upperBound..<s.endIndex
                }
                switch name {
                case "indices": return [.array(foundIndices.map { .number(Double($0)) })]
                case "index": return [foundIndices.isEmpty ? .null : .number(Double(foundIndices[0]))]
                case "rindex": return [foundIndices.last.map { .number(Double($0)) } ?? .null]
                default: return [.null]
                }
            } else if case .array(let items) = input {
                var foundIndices: [Int] = []
                for (i, item) in items.enumerated() {
                    if item == searchVal {
                        foundIndices.append(i)
                    }
                }
                switch name {
                case "indices": return [.array(foundIndices.map { .number(Double($0)) })]
                case "index": return [foundIndices.isEmpty ? .null : .number(Double(foundIndices[0]))]
                case "rindex": return [foundIndices.last.map { .number(Double($0)) } ?? .null]
                default: return [.null]
                }
            }
            return [.null]

        case "tojson":
            return [.string(input.minified())]

        case "fromjson":
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "fromjson")
            }
            return [try JSONParser.parse(s)]

        case "recurse":
            return recurseAll(input)

        case "leaf_paths":
            return [.array(leafPaths(input, prefix: []))]

        case "path":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("path requires 1 argument")
            }
            // path(f) returns the path to each output of f
            return try evalPaths(arg, input: input, currentPath: [])

        case "getpath":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("getpath requires 1 argument")
            }
            let results = try eval(arg, input: input)
            guard case .array(let pathComponents) = results.first else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: "other", context: "getpath")
            }
            var current = input
            for component in pathComponents {
                switch component {
                case .string(let key):
                    current = current[key] ?? .null
                case .number(let idx):
                    current = current[Int(idx)] ?? .null
                default:
                    return [.null]
                }
            }
            return [current]

        case "debug":
            // In our implementation, debug just passes through the input
            return [input]

        case "abs":
            guard case .number(let n) = input else {
                throw JQRuntimeError.typeMismatch(expected: "number", got: input.typeName.lowercased(), context: "abs")
            }
            return [.number(Swift.abs(n))]

        case "floor":
            guard case .number(let n) = input else {
                throw JQRuntimeError.typeMismatch(expected: "number", got: input.typeName.lowercased(), context: "floor")
            }
            return [.number(Foundation.floor(n))]

        case "ceil":
            guard case .number(let n) = input else {
                throw JQRuntimeError.typeMismatch(expected: "number", got: input.typeName.lowercased(), context: "ceil")
            }
            return [.number(Foundation.ceil(n))]

        case "round":
            guard case .number(let n) = input else {
                throw JQRuntimeError.typeMismatch(expected: "number", got: input.typeName.lowercased(), context: "round")
            }
            return [.number(Foundation.round(n))]

        case "sqrt":
            guard case .number(let n) = input else {
                throw JQRuntimeError.typeMismatch(expected: "number", got: input.typeName.lowercased(), context: "sqrt")
            }
            return [.number(Foundation.sqrt(n))]

        case "objects", "arrays", "strings", "numbers", "booleans", "nulls", "iterables", "scalars":
            return selectByType(name, input: input)

        case "ascii":
            // Return the ASCII value of the first character
            guard case .string(let s) = input, let first = s.first, let ascii = first.asciiValue else {
                return [.null]
            }
            return [.number(Double(ascii))]

        case "explode":
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "explode")
            }
            return [.array(s.unicodeScalars.map { .number(Double($0.value)) })]

        case "implode":
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "implode")
            }
            var result = ""
            for item in items {
                guard case .number(let n) = item, let scalar = Unicode.Scalar(UInt32(n)) else { continue }
                result.append(Character(scalar))
            }
            return [.string(result)]

        case "del":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("del requires 1 argument")
            }
            return try evalDel(arg, input: input)

        case "limit":
            guard args.count >= 2 else {
                throw JQRuntimeError.invalidArgument("limit requires 2 arguments")
            }
            let nResults = try eval(args[0], input: input)
            guard case .number(let n) = nResults.first else {
                throw JQRuntimeError.invalidArgument("limit: first argument must be a number")
            }
            let count = Int(n)
            let results = try eval(args[1], input: input)
            return Array(results.prefix(count))

        case "nth":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("nth requires at least 1 argument")
            }
            let nResults = try eval(arg, input: input)
            guard case .number(let n) = nResults.first else {
                throw JQRuntimeError.invalidArgument("nth: argument must be a number")
            }
            if args.count >= 2 {
                let results = try eval(args[1], input: input)
                let idx = Int(n)
                if idx >= 0 && idx < results.count {
                    return [results[idx]]
                }
                return [.null]
            }
            return [.null]

        case "in":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("in requires 1 argument")
            }
            let container = try eval(arg, input: input)
            guard let containerNode = container.first else { return [.bool(false)] }
            switch (input, containerNode) {
            case (.string(let key), .object(let dict, _)):
                return [.bool(dict[key] != nil)]
            case (.number(let idx), .array(let items)):
                return [.bool(Int(idx) >= 0 && Int(idx) < items.count)]
            default:
                return [.bool(false)]
            }

        case "isinfinite":
            guard case .number(let n) = input else { return [.bool(false)] }
            return [.bool(n.isInfinite)]

        case "isnan":
            guard case .number(let n) = input else { return [.bool(false)] }
            return [.bool(n.isNaN)]

        case "isnormal":
            guard case .number(let n) = input else { return [.bool(false)] }
            return [.bool(n.isNormal)]

        case "infinite":
            return [.number(Double.infinity)]

        case "nan":
            return [.number(Double.nan)]

        case "now":
            return [.number(Date().timeIntervalSince1970)]

        case "builtins":
            let builtinNames = [
                "length", "keys", "keys_unsorted", "values", "type", "has", "contains",
                "inside", "select", "map", "map_values", "to_entries", "from_entries",
                "with_entries", "add", "any", "all", "flatten", "reverse", "sort",
                "sort_by", "unique", "unique_by", "group_by", "min", "max", "min_by",
                "max_by", "first", "last", "range", "empty", "error", "not", "tostring",
                "tonumber", "ascii_downcase", "ascii_upcase", "ltrimstr", "rtrimstr",
                "startswith", "endswith", "split", "join", "test", "match", "indices",
                "index", "rindex", "tojson", "fromjson", "recurse", "leaf_paths",
                "path", "getpath", "debug", "abs", "floor", "ceil", "round", "sqrt",
                "explode", "implode", "del", "limit", "nth", "in", "isinfinite",
                "isnan", "isnormal", "infinite", "nan", "now", "builtins",
                "objects", "arrays", "strings", "numbers", "booleans", "nulls",
                "iterables", "scalars", "ascii", "transpose"
            ]
            return [.array(builtinNames.map { .string($0) })]

        case "transpose":
            guard case .array(let items) = input else {
                throw JQRuntimeError.typeMismatch(expected: "array", got: input.typeName.lowercased(), context: "transpose")
            }
            // Find max length
            var maxLen = 0
            for item in items {
                if case .array(let inner) = item {
                    maxLen = Swift.max(maxLen, inner.count)
                }
            }
            var result: [[JSONNode]] = Array(repeating: [], count: maxLen)
            for item in items {
                if case .array(let inner) = item {
                    for (i, val) in inner.enumerated() {
                        result[i].append(val)
                    }
                }
            }
            return [.array(result.map { .array($0) })]

        case "setpath":
            guard args.count >= 2 else {
                throw JQRuntimeError.invalidArgument("setpath requires 2 arguments")
            }
            let pathResults = try eval(args[0], input: input)
            let valueResults = try eval(args[1], input: input)
            guard case .array(let pathComponents) = pathResults.first,
                  let newValue = valueResults.first else {
                return [input]
            }
            let pathArr = pathComponents.compactMap { comp -> JSONPathComponent? in
                switch comp {
                case .string(let k): return .key(k)
                case .number(let n): return .index(Int(n))
                default: return nil
                }
            }
            return [input.replacing(at: pathArr, with: newValue)]

        case "delpaths":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("delpaths requires 1 argument")
            }
            let pathsResults = try eval(arg, input: input)
            guard case .array(let paths) = pathsResults.first else {
                return [input]
            }
            // Delete paths in reverse order to maintain validity
            var result = input
            let pathArrays = paths.compactMap { path -> [JSONPathComponent]? in
                guard case .array(let components) = path else { return nil }
                return components.compactMap { comp -> JSONPathComponent? in
                    switch comp {
                    case .string(let k): return .key(k)
                    case .number(let n): return .index(Int(n))
                    default: return nil
                    }
                }
            }
            for path in pathArrays.reversed() {
                result = deletePath(result, at: path)
            }
            return [result]

        case "sub":
            guard args.count >= 2 else {
                throw JQRuntimeError.invalidArgument("sub requires 2 arguments")
            }
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "sub")
            }
            let patternResults = try eval(args[0], input: input)
            let replacementResults = try eval(args[1], input: input)
            guard case .string(let pattern) = patternResults.first,
                  case .string(let replacement) = replacementResults.first else {
                return [input]
            }
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(s.startIndex..., in: s)
            let result = regex.stringByReplacingMatches(in: s, range: NSRange(location: range.location, length: min(1, range.length)), withTemplate: replacement)
            return [.string(result)]

        case "gsub":
            guard args.count >= 2 else {
                throw JQRuntimeError.invalidArgument("gsub requires 2 arguments")
            }
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "gsub")
            }
            let patternResults = try eval(args[0], input: input)
            let replacementResults = try eval(args[1], input: input)
            guard case .string(let pattern) = patternResults.first,
                  case .string(let replacement) = replacementResults.first else {
                return [input]
            }
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(s.startIndex..., in: s)
            let result = regex.stringByReplacingMatches(in: s, range: range, withTemplate: replacement)
            return [.string(result)]

        case "scan":
            guard let arg = args.first else {
                throw JQRuntimeError.invalidArgument("scan requires 1 argument")
            }
            guard case .string(let s) = input else {
                throw JQRuntimeError.typeMismatch(expected: "string", got: input.typeName.lowercased(), context: "scan")
            }
            let patternResults = try eval(arg, input: input)
            guard case .string(let pattern) = patternResults.first else {
                return [.array([])]
            }
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(s.startIndex..., in: s)
            let matches = regex.matches(in: s, range: range)
            var results: [JSONNode] = []
            for m in matches {
                if m.numberOfRanges > 1 {
                    var captures: [JSONNode] = []
                    for i in 1..<m.numberOfRanges {
                        let r = m.range(at: i)
                        if r.location != NSNotFound, let swiftRange = Range(r, in: s) {
                            captures.append(.string(String(s[swiftRange])))
                        }
                    }
                    results.append(.array(captures))
                } else if let r = Range(m.range, in: s) {
                    results.append(.array([.string(String(s[r]))]))
                }
            }
            return results

        default:
            throw JQRuntimeError.customError("Unknown function: \(name)")
        }
    }

    // MARK: - Helper functions

    private static func isTruthy(_ node: JSONNode) -> Bool {
        switch node {
        case .bool(let b): return b
        case .null: return false
        default: return true
        }
    }

    private static func nodeLength(_ node: JSONNode) -> Int {
        switch node {
        case .object(_, let keys): return keys.count
        case .array(let items): return items.count
        case .string(let s): return s.count
        case .null: return 0
        default: return 0 // numbers and bools have no length in jq, but return 0
        }
    }

    private static func jqTypeName(_ node: JSONNode) -> String {
        switch node {
        case .object: return "object"
        case .array: return "array"
        case .string: return "string"
        case .number: return "number"
        case .bool: return "boolean"
        case .null: return "null"
        }
    }

    private static func compareNodes(_ a: JSONNode, _ b: JSONNode, op: ComparisonOp) -> Bool {
        let cmp = nodeCompare(a, b)
        switch op {
        case .eq: return cmp == 0
        case .neq: return cmp != 0
        case .lt: return cmp < 0
        case .lte: return cmp <= 0
        case .gt: return cmp > 0
        case .gte: return cmp >= 0
        }
    }

    private static func nodeCompare(_ a: JSONNode, _ b: JSONNode) -> Int {
        // jq type ordering: null < false < true < number < string < array < object
        let aOrder = typeOrder(a)
        let bOrder = typeOrder(b)
        if aOrder != bOrder { return aOrder < bOrder ? -1 : 1 }

        switch (a, b) {
        case (.null, .null): return 0
        case (.bool(let ab), .bool(let bb)):
            if ab == bb { return 0 }
            return ab ? 1 : -1
        case (.number(let an), .number(let bn)):
            if an == bn { return 0 }
            return an < bn ? -1 : 1
        case (.string(let as_), .string(let bs)):
            return as_ < bs ? -1 : (as_ > bs ? 1 : 0)
        case (.array(let ai), .array(let bi)):
            for (x, y) in zip(ai, bi) {
                let c = nodeCompare(x, y)
                if c != 0 { return c }
            }
            return ai.count < bi.count ? -1 : (ai.count > bi.count ? 1 : 0)
        case (.object(let ad, let ak), .object(let bd, let bk)):
            let sortedA = ak.sorted()
            let sortedB = bk.sorted()
            for (ka, kb) in zip(sortedA, sortedB) {
                let kc = ka < kb ? -1 : (ka > kb ? 1 : 0)
                if kc != 0 { return kc }
                let vc = nodeCompare(ad[ka] ?? .null, bd[kb] ?? .null)
                if vc != 0 { return vc }
            }
            return sortedA.count < sortedB.count ? -1 : (sortedA.count > sortedB.count ? 1 : 0)
        default: return 0
        }
    }

    private static func typeOrder(_ node: JSONNode) -> Int {
        switch node {
        case .null: return 0
        case .bool(false): return 1
        case .bool(true): return 2
        case .number: return 3
        case .string: return 4
        case .array: return 5
        case .object: return 6
        }
    }

    private static func performArithmetic(_ a: JSONNode, _ b: JSONNode, op: ArithOp) throws -> JSONNode {
        // Handle null arithmetic (jq semantics: null is identity for +)
        if case .null = a {
            if op == .add { return b }
        }
        if case .null = b {
            if op == .add { return a }
        }

        switch (a, b, op) {
        case (.number(let an), .number(let bn), .add): return .number(an + bn)
        case (.number(let an), .number(let bn), .sub): return .number(an - bn)
        case (.number(let an), .number(let bn), .mul): return .number(an * bn)
        case (.number(let an), .number(let bn), .div):
            guard bn != 0 else { throw JQRuntimeError.divisionByZero }
            return .number(an / bn)
        case (.number(let an), .number(let bn), .mod):
            guard bn != 0 else { throw JQRuntimeError.divisionByZero }
            return .number(Double(Int(an) % Int(bn)))

        case (.string(let as_), .string(let bs), .add):
            return .string(as_ + bs)

        case (.array(let ai), .array(let bi), .add):
            return .array(ai + bi)

        case (.object(var ad, var ak), .object(let bd, let bk), .add):
            for key in bk {
                if ad[key] == nil {
                    ak.append(key)
                }
                ad[key] = bd[key]
            }
            return .object(ad, orderedKeys: ak)

        default:
            throw JQRuntimeError.typeMismatch(
                expected: "compatible types",
                got: "\(a.typeName.lowercased()) and \(b.typeName.lowercased())",
                context: "arithmetic"
            )
        }
    }

    private static func recurseAll(_ node: JSONNode) -> [JSONNode] {
        var results: [JSONNode] = [node]
        switch node {
        case .object(let dict, let keys):
            for key in keys {
                if let value = dict[key] {
                    results.append(contentsOf: recurseAll(value))
                }
            }
        case .array(let items):
            for item in items {
                results.append(contentsOf: recurseAll(item))
            }
        default:
            break
        }
        return results
    }

    private static func flattenArray(_ items: [JSONNode], depth: Int) -> [JSONNode] {
        if depth <= 0 { return items }
        var result: [JSONNode] = []
        for item in items {
            if case .array(let inner) = item {
                result.append(contentsOf: flattenArray(inner, depth: depth - 1))
            } else {
                result.append(item)
            }
        }
        return result
    }

    private static func nodeContains(_ container: JSONNode, _ target: JSONNode) -> Bool {
        if container == target { return true }
        switch (container, target) {
        case (.string(let cs), .string(let ts)):
            return cs.contains(ts)
        case (.array(let ci), .array(let ti)):
            return ti.allSatisfy { targetItem in
                ci.contains { containerItem in nodeContains(containerItem, targetItem) }
            }
        case (.object(let cd, _), .object(let td, let tk)):
            return tk.allSatisfy { key in
                guard let cv = cd[key], let tv = td[key] else { return false }
                return nodeContains(cv, tv)
            }
        default:
            return false
        }
    }

    private static func leafPaths(_ node: JSONNode, prefix: [JSONNode]) -> [JSONNode] {
        switch node {
        case .object(let dict, let keys):
            if keys.isEmpty { return [.array(prefix)] }
            var results: [JSONNode] = []
            for key in keys {
                if let value = dict[key] {
                    results.append(contentsOf: leafPaths(value, prefix: prefix + [.string(key)]))
                }
            }
            return results
        case .array(let items):
            if items.isEmpty { return [.array(prefix)] }
            var results: [JSONNode] = []
            for (i, item) in items.enumerated() {
                results.append(contentsOf: leafPaths(item, prefix: prefix + [.number(Double(i))]))
            }
            return results
        default:
            return [.array(prefix)]
        }
    }

    private static func evalPaths(_ expr: JQExpression, input: JSONNode, currentPath: [JSONNode]) throws -> [JSONNode] {
        // Simplified path tracking — returns paths to values selected by expr
        switch expr {
        case .field(let name, _):
            return [.array(currentPath + [.string(name)])]
        case .index(let idx):
            return [.array(currentPath + [.number(Double(idx))])]
        case .iterator:
            switch input {
            case .object(_, let keys):
                return keys.map { .array(currentPath + [.string($0)]) }
            case .array(let items):
                return items.indices.map { .array(currentPath + [.number(Double($0))]) }
            default:
                return []
            }
        case .pipe(let left, let right):
            let leftPaths = try evalPaths(left, input: input, currentPath: currentPath)
            var results: [JSONNode] = []
            for pathNode in leftPaths {
                guard case .array(let pathComponents) = pathNode else { continue }
                var current = input
                for comp in pathComponents {
                    switch comp {
                    case .string(let k):
                        current = current[k] ?? .null
                    case .number(let n):
                        current = current[Int(n)] ?? .null
                    default: break
                    }
                }
                results.append(contentsOf: try evalPaths(right, input: current, currentPath: pathComponents))
            }
            return results
        default:
            // For complex expressions, try to evaluate and return empty
            return []
        }
    }

    private static func selectByType(_ typeName: String, input: JSONNode) -> [JSONNode] {
        switch typeName {
        case "objects":
            if case .object = input { return [input] }
        case "arrays":
            if case .array = input { return [input] }
        case "strings":
            if case .string = input { return [input] }
        case "numbers":
            if case .number = input { return [input] }
        case "booleans":
            if case .bool = input { return [input] }
        case "nulls":
            if case .null = input { return [input] }
        case "iterables":
            if input.isContainer { return [input] }
        case "scalars":
            if !input.isContainer { return [input] }
        default:
            break
        }
        return []
    }

    private static func deletePath(_ node: JSONNode, at path: [JSONPathComponent]) -> JSONNode {
        guard let first = path.first else { return .null }

        if path.count == 1 {
            switch (node, first) {
            case (.object(var dict, var keys), .key(let k)):
                dict.removeValue(forKey: k)
                keys.removeAll { $0 == k }
                return .object(dict, orderedKeys: keys)
            case (.array(var items), .index(let i)) where i >= 0 && i < items.count:
                items.remove(at: i)
                return .array(items)
            default:
                return node
            }
        }

        let rest = Array(path.dropFirst())
        switch (node, first) {
        case (.object(var dict, let keys), .key(let k)):
            if let child = dict[k] {
                dict[k] = deletePath(child, at: rest)
            }
            return .object(dict, orderedKeys: keys)
        case (.array(var items), .index(let i)) where i >= 0 && i < items.count:
            items[i] = deletePath(items[i], at: rest)
            return .array(items)
        default:
            return node
        }
    }

    private static func evalDel(_ expr: JQExpression, input: JSONNode) throws -> [JSONNode] {
        switch expr {
        case .field(let name, _):
            guard case .object(var dict, var keys) = input else { return [input] }
            dict.removeValue(forKey: name)
            keys.removeAll { $0 == name }
            return [.object(dict, orderedKeys: keys)]
        case .index(let idx):
            guard case .array(var items) = input else { return [input] }
            let effectiveIdx = idx < 0 ? items.count + idx : idx
            if effectiveIdx >= 0 && effectiveIdx < items.count {
                items.remove(at: effectiveIdx)
            }
            return [.array(items)]
        case .pipe(let left, let right):
            let leftResults = try eval(left, input: input)
            var result = input
            for leftResult in leftResults {
                let deleted = try evalDel(right, input: leftResult)
                if let first = deleted.first {
                    result = first
                }
            }
            return [result]
        case .iterator:
            switch input {
            case .object: return [.object([:], orderedKeys: [])]
            case .array: return [.array([])]
            default: return [input]
            }
        default:
            return [input]
        }
    }

    private static func evalObjectConstruct(_ pairs: [(key: JQExpression.ObjKey, value: JQExpression)], input: JSONNode) throws -> [JSONNode] {
        var dict: [String: JSONNode] = [:]
        var keys: [String] = []

        for pair in pairs {
            let keyStr: String
            switch pair.key {
            case .name(let name):
                keyStr = name
            case .expr(let keyExpr):
                let keyResults = try eval(keyExpr, input: input)
                guard case .string(let k) = keyResults.first else {
                    throw JQRuntimeError.typeMismatch(expected: "string", got: "other", context: "object key")
                }
                keyStr = k
            }

            let valueResults = try eval(pair.value, input: input)
            let value = valueResults.first ?? .null

            if dict[keyStr] == nil {
                keys.append(keyStr)
            }
            dict[keyStr] = value
        }

        return [.object(dict, orderedKeys: keys)]
    }
}
