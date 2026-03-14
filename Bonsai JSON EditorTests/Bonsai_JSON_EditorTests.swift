import Testing
import Foundation
@testable import Bonsai_JSON_Editor

// MARK: - JSONParser Tests

struct JSONParserTests {

    @Test func parseEmptyObject() throws {
        let result = try JSONParser.parse("{}")
        #expect(result == .object([:], orderedKeys: []))
    }

    @Test func parseEmptyArray() throws {
        let result = try JSONParser.parse("[]")
        #expect(result == .array([]))
    }

    @Test func parseString() throws {
        let result = try JSONParser.parse("\"hello\"")
        #expect(result == .string("hello"))
    }

    @Test func parseNumber() throws {
        let result = try JSONParser.parse("42")
        #expect(result == .number(42))
    }

    @Test func parseNegativeNumber() throws {
        let result = try JSONParser.parse("-3.14")
        #expect(result == .number(-3.14))
    }

    @Test func parseExponentialNumber() throws {
        let result = try JSONParser.parse("1.5e10")
        #expect(result == .number(1.5e10))
    }

    @Test func parseBoolTrue() throws {
        let result = try JSONParser.parse("true")
        #expect(result == .bool(true))
    }

    @Test func parseBoolFalse() throws {
        let result = try JSONParser.parse("false")
        #expect(result == .bool(false))
    }

    @Test func parseNull() throws {
        let result = try JSONParser.parse("null")
        #expect(result == .null)
    }

    @Test func parseSimpleObject() throws {
        let result = try JSONParser.parse("""
        {"name": "Alice", "age": 30}
        """)
        #expect(result == .object(
            ["name": .string("Alice"), "age": .number(30)],
            orderedKeys: ["name", "age"]
        ))
    }

    @Test func parseNestedObject() throws {
        let result = try JSONParser.parse("""
        {"user": {"name": "Alice", "address": {"city": "NYC"}}}
        """)
        guard case .object(let dict, _) = result else {
            Issue.record("Expected object")
            return
        }
        guard case .object(let userDict, _) = dict["user"] else {
            Issue.record("Expected user object")
            return
        }
        guard case .object(let addrDict, _) = userDict["address"] else {
            Issue.record("Expected address object")
            return
        }
        #expect(addrDict["city"] == .string("NYC"))
    }

    @Test func parseArray() throws {
        let result = try JSONParser.parse("[1, 2, 3]")
        #expect(result == .array([.number(1), .number(2), .number(3)]))
    }

    @Test func parseNestedArray() throws {
        let result = try JSONParser.parse("[[1, 2], [3, 4]]")
        #expect(result == .array([
            .array([.number(1), .number(2)]),
            .array([.number(3), .number(4)])
        ]))
    }

    @Test func parseMixedTypes() throws {
        let result = try JSONParser.parse("""
        {"str": "hello", "num": 42, "bool": true, "nil": null, "arr": [1]}
        """)
        guard case .object(let dict, let keys) = result else {
            Issue.record("Expected object")
            return
        }
        #expect(keys == ["str", "num", "bool", "nil", "arr"])
        #expect(dict["str"] == .string("hello"))
        #expect(dict["num"] == .number(42))
        #expect(dict["bool"] == .bool(true))
        #expect(dict["nil"] == .null)
        #expect(dict["arr"] == .array([.number(1)]))
    }

    @Test func parseUnicodeEscapes() throws {
        let result = try JSONParser.parse("\"\\u0048\\u0065\\u006C\\u006C\\u006F\"")
        #expect(result == .string("Hello"))
    }

    @Test func parseEscapedCharacters() throws {
        let result = try JSONParser.parse("\"line1\\nline2\\ttab\\\\backslash\\\"quote\"")
        #expect(result == .string("line1\nline2\ttab\\backslash\"quote"))
    }

    @Test func parsePreservesKeyOrder() throws {
        let result = try JSONParser.parse("""
        {"z": 1, "a": 2, "m": 3}
        """)
        guard case .object(_, let keys) = result else {
            Issue.record("Expected object")
            return
        }
        #expect(keys == ["z", "a", "m"])
    }

    @Test func parseErrorInvalidJSON() {
        #expect(throws: JSONParseError.self) {
            try JSONParser.parse("{invalid}")
        }
    }

    @Test func parseErrorUnterminatedString() {
        #expect(throws: JSONParseError.self) {
            try JSONParser.parse("\"unterminated")
        }
    }

    @Test func parseErrorTrailingComma() {
        // Trailing commas are not valid JSON
        #expect(throws: JSONParseError.self) {
            try JSONParser.parse("[1, 2,]")
        }
    }
}

// MARK: - JQLexer Tests

struct JQLexerTests {

    @Test func tokenizeDot() throws {
        let tokens = try JQLexer.tokenize(".")
        #expect(tokens == [.dot, .eof])
    }

    @Test func tokenizeFieldAccess() throws {
        let tokens = try JQLexer.tokenize(".name")
        #expect(tokens == [.dot, .identifier("name"), .eof])
    }

    @Test func tokenizePipe() throws {
        let tokens = try JQLexer.tokenize(". | .name")
        #expect(tokens == [.dot, .pipe, .dot, .identifier("name"), .eof])
    }

    @Test func tokenizeArrayIndex() throws {
        let tokens = try JQLexer.tokenize(".[0]")
        #expect(tokens == [.dot, .lbracket, .intLiteral(0), .rbracket, .eof])
    }

    @Test func tokenizeIterator() throws {
        let tokens = try JQLexer.tokenize(".[]")
        #expect(tokens == [.dot, .lbracket, .rbracket, .eof])
    }

    @Test func tokenizeComparison() throws {
        let tokens = try JQLexer.tokenize(".age == 30")
        #expect(tokens == [.dot, .identifier("age"), .op(.eq), .intLiteral(30), .eof])
    }

    @Test func tokenizeArithmetic() throws {
        let tokens = try JQLexer.tokenize(".age + 1")
        #expect(tokens == [.dot, .identifier("age"), .op(.add), .intLiteral(1), .eof])
    }

    @Test func tokenizeStringLiteral() throws {
        let tokens = try JQLexer.tokenize("\"hello\"")
        #expect(tokens == [.stringLiteral("hello"), .eof])
    }

    @Test func tokenizeKeywords() throws {
        let tokens = try JQLexer.tokenize("if true then 1 else 2 end")
        #expect(tokens == [
            .keyword(.if), .keyword(.true), .keyword(.then),
            .intLiteral(1), .keyword(.else), .intLiteral(2),
            .keyword(.end), .eof
        ])
    }

    @Test func tokenizeBuiltinFunction() throws {
        let tokens = try JQLexer.tokenize("map(.name)")
        #expect(tokens == [
            .identifier("map"), .lparen, .dot,
            .identifier("name"), .rparen, .eof
        ])
    }

    @Test func tokenizeSelectExpression() throws {
        let tokens = try JQLexer.tokenize("select(.age > 18)")
        #expect(tokens == [
            .identifier("select"), .lparen, .dot,
            .identifier("age"), .op(.gt), .intLiteral(18),
            .rparen, .eof
        ])
    }
}

// MARK: - JQParser Tests

struct JQParserTests {

    @Test func parseIdentity() throws {
        let tokens = try JQLexer.tokenize(".")
        let expr = try JQParser.parse(tokens)
        if case .identity = expr { } else {
            Issue.record("Expected identity, got \(expr)")
        }
    }

    @Test func parseFieldAccess() throws {
        let tokens = try JQLexer.tokenize(".name")
        let expr = try JQParser.parse(tokens)
        if case .field("name", optional: false) = expr { } else {
            Issue.record("Expected field access, got \(expr)")
        }
    }

    @Test func parsePipe() throws {
        let tokens = try JQLexer.tokenize(". | .name")
        let expr = try JQParser.parse(tokens)
        if case .pipe(.identity, .field("name", optional: false)) = expr { } else {
            Issue.record("Expected pipe, got \(expr)")
        }
    }

    @Test func parseArrayIndex() throws {
        let tokens = try JQLexer.tokenize(".[0]")
        let expr = try JQParser.parse(tokens)
        if case .index(0) = expr { } else {
            Issue.record("Expected index, got \(expr)")
        }
    }

    @Test func parseIterator() throws {
        let tokens = try JQLexer.tokenize(".[]")
        let expr = try JQParser.parse(tokens)
        if case .iterator(optional: false) = expr { } else {
            Issue.record("Expected iterator, got \(expr)")
        }
    }

    @Test func parseArrayConstruction() throws {
        let tokens = try JQLexer.tokenize("[.name]")
        let expr = try JQParser.parse(tokens)
        if case .arrayConstruct(let inner) = expr {
            if case .field("name", optional: false) = inner { } else {
                Issue.record("Expected field in array construct, got \(String(describing: inner))")
            }
        } else {
            Issue.record("Expected array construct, got \(expr)")
        }
    }

    @Test func parseComparison() throws {
        let tokens = try JQLexer.tokenize(".age == 30")
        let expr = try JQParser.parse(tokens)
        if case .comparison(_, .eq, _) = expr { } else {
            Issue.record("Expected comparison, got \(expr)")
        }
    }

    @Test func parseArithmetic() throws {
        let tokens = try JQLexer.tokenize(".age + 1")
        let expr = try JQParser.parse(tokens)
        if case .arithmetic(_, .add, _) = expr { } else {
            Issue.record("Expected arithmetic, got \(expr)")
        }
    }
}

// MARK: - JQEvaluator Tests

struct JQEvaluatorTests {

    let simpleObject: JSONNode
    let usersObject: JSONNode

    init() throws {
        simpleObject = try JSONParser.parse("""
        {"name": "Alice", "age": 30}
        """)
        usersObject = try JSONParser.parse("""
        {"users": [{"name": "Alice"}, {"name": "Bob"}]}
        """)
    }

    // --- Basic tests ---

    @Test func evalIdentity() throws {
        let results = try JQEvaluator.evaluate(expression: ".", input: simpleObject)
        #expect(results.count == 1)
        #expect(results[0] == simpleObject)
    }

    @Test func evalFieldAccess() throws {
        let results = try JQEvaluator.evaluate(expression: ".name", input: simpleObject)
        #expect(results == [.string("Alice")])
    }

    @Test func evalArithmetic() throws {
        let results = try JQEvaluator.evaluate(expression: ".age + 1", input: simpleObject)
        #expect(results == [.number(31)])
    }

    @Test func evalKeys() throws {
        let results = try JQEvaluator.evaluate(expression: "keys", input: simpleObject)
        #expect(results == [.array([.string("age"), .string("name")])])
    }

    @Test func evalToEntries() throws {
        let results = try JQEvaluator.evaluate(expression: "to_entries", input: simpleObject)
        #expect(results.count == 1)
        guard case .array(let entries) = results[0] else {
            Issue.record("Expected array")
            return
        }
        #expect(entries.count == 2)
    }

    // --- Users tests ---

    @Test func evalNestedFieldAccess() throws {
        let results = try JQEvaluator.evaluate(expression: ".users[].name", input: usersObject)
        #expect(results == [.string("Alice"), .string("Bob")])
    }

    @Test func evalMapName() throws {
        let results = try JQEvaluator.evaluate(expression: ".users | map(.name)", input: usersObject)
        #expect(results == [.array([.string("Alice"), .string("Bob")])])
    }

    @Test func evalMapSelect() throws {
        let results = try JQEvaluator.evaluate(
            expression: ".users | map(select(.name == \"Alice\"))",
            input: usersObject
        )
        #expect(results.count == 1)
        guard case .array(let items) = results[0] else {
            Issue.record("Expected array")
            return
        }
        #expect(items.count == 1)
        #expect(items[0]["name"] == .string("Alice"))
    }

    @Test func evalArrayConstruct() throws {
        let results = try JQEvaluator.evaluate(
            expression: "[.users[] | .name]",
            input: usersObject
        )
        #expect(results == [.array([.string("Alice"), .string("Bob")])])
    }

    // --- Type functions ---

    @Test func evalLength() throws {
        let results = try JQEvaluator.evaluate(expression: "length", input: simpleObject)
        #expect(results == [.number(2)])
    }

    @Test func evalType() throws {
        let results = try JQEvaluator.evaluate(expression: "type", input: simpleObject)
        #expect(results == [.string("object")])
    }

    @Test func evalValues() throws {
        let results = try JQEvaluator.evaluate(expression: "values", input: simpleObject)
        #expect(results.count == 1)
        guard case .array(let items) = results[0] else {
            Issue.record("Expected array")
            return
        }
        #expect(items.count == 2)
    }

    // --- Array operations ---

    @Test func evalSort() throws {
        let arr = JSONNode.array([.number(3), .number(1), .number(2)])
        let results = try JQEvaluator.evaluate(expression: "sort", input: arr)
        #expect(results == [.array([.number(1), .number(2), .number(3)])])
    }

    @Test func evalReverse() throws {
        let arr = JSONNode.array([.number(1), .number(2), .number(3)])
        let results = try JQEvaluator.evaluate(expression: "reverse", input: arr)
        #expect(results == [.array([.number(3), .number(2), .number(1)])])
    }

    @Test func evalUnique() throws {
        let arr = JSONNode.array([.number(1), .number(2), .number(1), .number(3)])
        let results = try JQEvaluator.evaluate(expression: "unique", input: arr)
        #expect(results == [.array([.number(1), .number(2), .number(3)])])
    }

    @Test func evalFlatten() throws {
        let arr = JSONNode.array([
            .array([.number(1), .number(2)]),
            .array([.number(3)])
        ])
        let results = try JQEvaluator.evaluate(expression: "flatten", input: arr)
        #expect(results == [.array([.number(1), .number(2), .number(3)])])
    }

    @Test func evalAdd() throws {
        let arr = JSONNode.array([.number(1), .number(2), .number(3)])
        let results = try JQEvaluator.evaluate(expression: "add", input: arr)
        #expect(results == [.number(6)])
    }

    // --- String operations ---

    @Test func evalAsciiDowncase() throws {
        let results = try JQEvaluator.evaluate(expression: "ascii_downcase", input: .string("HELLO"))
        #expect(results == [.string("hello")])
    }

    @Test func evalAsciiUpcase() throws {
        let results = try JQEvaluator.evaluate(expression: "ascii_upcase", input: .string("hello"))
        #expect(results == [.string("HELLO")])
    }

    @Test func evalSplit() throws {
        let results = try JQEvaluator.evaluate(expression: "split(\",\")", input: .string("a,b,c"))
        #expect(results == [.array([.string("a"), .string("b"), .string("c")])])
    }

    @Test func evalJoin() throws {
        let arr = JSONNode.array([.string("a"), .string("b"), .string("c")])
        let results = try JQEvaluator.evaluate(expression: "join(\"-\")", input: arr)
        #expect(results == [.string("a-b-c")])
    }

    @Test func evalStartswith() throws {
        let results = try JQEvaluator.evaluate(expression: "startswith(\"hel\")", input: .string("hello"))
        #expect(results == [.bool(true)])
    }

    @Test func evalEndswith() throws {
        let results = try JQEvaluator.evaluate(expression: "endswith(\"llo\")", input: .string("hello"))
        #expect(results == [.bool(true)])
    }

    @Test func evalTest() throws {
        let results = try JQEvaluator.evaluate(expression: "test(\"^h\")", input: .string("hello"))
        #expect(results == [.bool(true)])
    }

    // --- Conversion functions ---

    @Test func evalTostring() throws {
        let results = try JQEvaluator.evaluate(expression: "tostring", input: .number(42))
        #expect(results == [.string("42")])
    }

    @Test func evalTonumber() throws {
        let results = try JQEvaluator.evaluate(expression: "tonumber", input: .string("42"))
        #expect(results == [.number(42)])
    }

    @Test func evalTojson() throws {
        let obj = JSONNode.object(["a": .number(1)], orderedKeys: ["a"])
        let results = try JQEvaluator.evaluate(expression: "tojson", input: obj)
        #expect(results == [.string("{\"a\":1}")])
    }

    // --- Conditional ---

    @Test func evalIfThenElse() throws {
        let results = try JQEvaluator.evaluate(
            expression: "if .age > 18 then \"adult\" else \"minor\" end",
            input: simpleObject
        )
        #expect(results == [.string("adult")])
    }

    // --- Has ---

    @Test func evalHas() throws {
        let results = try JQEvaluator.evaluate(expression: "has(\"name\")", input: simpleObject)
        #expect(results == [.bool(true)])
    }

    @Test func evalHasMissing() throws {
        let results = try JQEvaluator.evaluate(expression: "has(\"email\")", input: simpleObject)
        #expect(results == [.bool(false)])
    }

    // --- Null arithmetic ---

    @Test func evalNullAddition() throws {
        let input = JSONNode.object(["x": .null], orderedKeys: ["x"])
        let results = try JQEvaluator.evaluate(expression: ".x + 1", input: input)
        #expect(results == [.number(1)])
    }

    // --- Select ---

    @Test func evalSelectFilter() throws {
        let arr = JSONNode.array([.number(1), .number(2), .number(3), .number(4)])
        let results = try JQEvaluator.evaluate(expression: "[.[] | select(. > 2)]", input: arr)
        #expect(results == [.array([.number(3), .number(4)])])
    }

    // --- Object construction ---

    @Test func evalObjectConstruct() throws {
        let results = try JQEvaluator.evaluate(
            expression: "{name: .name, years: .age}",
            input: simpleObject
        )
        #expect(results.count == 1)
        guard case .object(let dict, _) = results[0] else {
            Issue.record("Expected object")
            return
        }
        #expect(dict["name"] == .string("Alice"))
        #expect(dict["years"] == .number(30))
    }

    // --- Contains ---

    @Test func evalContains() throws {
        let results = try JQEvaluator.evaluate(expression: "contains(\"ell\")", input: .string("hello"))
        #expect(results == [.bool(true)])
    }

    // --- Not ---

    @Test func evalNot() throws {
        let results = try JQEvaluator.evaluate(expression: ". | not", input: .bool(false))
        #expect(results == [.bool(true)])
    }

    // --- Range ---

    @Test func evalRange() throws {
        let results = try JQEvaluator.evaluate(expression: "range(3)", input: .null)
        #expect(results == [.number(0), .number(1), .number(2)])
    }

    // --- Abs ---

    @Test func evalAbs() throws {
        let results = try JQEvaluator.evaluate(expression: "abs", input: .number(-5))
        #expect(results == [.number(5)])
    }

    // --- Floor/Ceil/Round ---

    @Test func evalFloor() throws {
        let results = try JQEvaluator.evaluate(expression: "floor", input: .number(3.7))
        #expect(results == [.number(3)])
    }

    @Test func evalCeil() throws {
        let results = try JQEvaluator.evaluate(expression: "ceil", input: .number(3.2))
        #expect(results == [.number(4)])
    }

    // --- Slicing ---

    @Test func evalSlice() throws {
        let arr = JSONNode.array([.number(0), .number(1), .number(2), .number(3), .number(4)])
        let results = try JQEvaluator.evaluate(expression: ".[2:4]", input: arr)
        #expect(results == [.array([.number(2), .number(3)])])
    }

    // --- Min/Max ---

    @Test func evalMin() throws {
        let arr = JSONNode.array([.number(3), .number(1), .number(2)])
        let results = try JQEvaluator.evaluate(expression: "min", input: arr)
        #expect(results == [.number(1)])
    }

    @Test func evalMax() throws {
        let arr = JSONNode.array([.number(3), .number(1), .number(2)])
        let results = try JQEvaluator.evaluate(expression: "max", input: arr)
        #expect(results == [.number(3)])
    }
}

// MARK: - JSONNode Tests

struct JSONNodeTests {

    @Test func prettyPrint() throws {
        let node = JSONNode.object(
            ["name": .string("Alice"), "age": .number(30)],
            orderedKeys: ["name", "age"]
        )
        let pretty = node.prettyPrinted()
        #expect(pretty.contains("\"name\": \"Alice\""))
        #expect(pretty.contains("\"age\": 30"))
    }

    @Test func minified() throws {
        let node = JSONNode.object(
            ["a": .number(1), "b": .number(2)],
            orderedKeys: ["a", "b"]
        )
        let mini = node.minified()
        #expect(mini == "{\"a\":1,\"b\":2}")
    }

    @Test func nodeAccess() throws {
        let node = try JSONParser.parse("""
        {"users": [{"name": "Alice"}, {"name": "Bob"}]}
        """)
        let path: [JSONPathComponent] = [.key("users"), .index(0), .key("name")]
        let result = node.node(at: path)
        #expect(result == .string("Alice"))
    }

    @Test func nodeReplace() throws {
        let node = try JSONParser.parse("""
        {"name": "Alice", "age": 30}
        """)
        let path: [JSONPathComponent] = [.key("name")]
        let updated = node.replacing(at: path, with: .string("Bob"))
        #expect(updated["name"] == .string("Bob"))
    }

    @Test func childCount() {
        let obj = JSONNode.object(["a": .number(1), "b": .number(2)], orderedKeys: ["a", "b"])
        #expect(obj.childCount == 2)

        let arr = JSONNode.array([.number(1), .number(2), .number(3)])
        #expect(arr.childCount == 3)

        let str = JSONNode.string("hello")
        #expect(str.childCount == 0)
    }

    @Test func orderedChildren() {
        let obj = JSONNode.object(
            ["z": .number(1), "a": .number(2)],
            orderedKeys: ["z", "a"]
        )
        let children = obj.orderedChildren
        #expect(children[0].label == "z")
        #expect(children[1].label == "a")
    }

    @Test func codable() throws {
        let original = try JSONParser.parse("""
        {"name": "Alice", "items": [1, true, null]}
        """)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONNode.self, from: data)
        #expect(decoded == original)
    }
}
