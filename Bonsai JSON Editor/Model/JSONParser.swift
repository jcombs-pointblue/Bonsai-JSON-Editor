import Foundation

/// Errors thrown during JSON parsing, including location information
struct JSONParseError: LocalizedError {
    let message: String
    let line: Int
    let column: Int

    var errorDescription: String? {
        "Parse error at line \(line), column \(column): \(message)"
    }
}

/// Hand-written recursive descent JSON parser that preserves key insertion order.
struct JSONParser {
    private let input: [Character]
    private var position: Int = 0
    private var line: Int = 1
    private var column: Int = 1

    private init(_ string: String) {
        self.input = Array(string)
    }

    /// Parse a JSON string into a JSONNode tree.
    static func parse(_ input: String) throws -> JSONNode {
        var parser = JSONParser(input)
        parser.skipWhitespace()
        let result = try parser.parseValue()
        parser.skipWhitespace()
        if parser.position < parser.input.count {
            throw parser.error("Unexpected content after JSON value")
        }
        return result
    }

    // MARK: - Core parsing

    private mutating func parseValue() throws -> JSONNode {
        guard position < input.count else {
            throw error("Unexpected end of input")
        }

        switch input[position] {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"": return try .string(parseString())
        case "t", "f": return try parseBool()
        case "n": return try parseNull()
        case "-", "0"..."9": return try parseNumber()
        default:
            throw error("Unexpected character '\(input[position])'")
        }
    }

    private mutating func parseObject() throws -> JSONNode {
        try expect("{")
        skipWhitespace()

        var dict: [String: JSONNode] = [:]
        var orderedKeys: [String] = []

        if peek() == "}" {
            advance()
            return .object(dict, orderedKeys: orderedKeys)
        }

        while true {
            skipWhitespace()
            guard peek() == "\"" else {
                throw error("Expected string key in object")
            }
            let key = try parseString()
            skipWhitespace()
            try expect(":")
            skipWhitespace()
            let value = try parseValue()

            dict[key] = value
            orderedKeys.append(key)

            skipWhitespace()
            if peek() == "," {
                advance()
            } else {
                break
            }
        }

        try expect("}")
        return .object(dict, orderedKeys: orderedKeys)
    }

    private mutating func parseArray() throws -> JSONNode {
        try expect("[")
        skipWhitespace()

        var items: [JSONNode] = []

        if peek() == "]" {
            advance()
            return .array(items)
        }

        while true {
            skipWhitespace()
            let value = try parseValue()
            items.append(value)

            skipWhitespace()
            if peek() == "," {
                advance()
            } else {
                break
            }
        }

        try expect("]")
        return .array(items)
    }

    private mutating func parseString() throws -> String {
        try expect("\"")
        var result = ""

        while position < input.count {
            let ch = input[position]
            if ch == "\"" {
                advance()
                return result
            } else if ch == "\\" {
                advance()
                guard position < input.count else {
                    throw error("Unexpected end of input in string escape")
                }
                let escaped = input[position]
                advance()
                switch escaped {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "u":
                    let codePoint = try parseUnicodeEscape()
                    // Handle surrogate pairs
                    if codePoint >= 0xD800 && codePoint <= 0xDBFF {
                        // High surrogate — expect \uXXXX low surrogate
                        guard position + 1 < input.count,
                              input[position] == "\\",
                              input[position + 1] == "u" else {
                            throw error("Expected low surrogate after high surrogate")
                        }
                        advance() // skip backslash
                        advance() // skip 'u'
                        let lowSurrogate = try parseUnicodeEscape()
                        guard lowSurrogate >= 0xDC00 && lowSurrogate <= 0xDFFF else {
                            throw error("Invalid low surrogate value")
                        }
                        let combined = 0x10000 + (Int(codePoint - 0xD800) << 10) + Int(lowSurrogate - 0xDC00)
                        guard let scalar = Unicode.Scalar(combined) else {
                            throw error("Invalid combined surrogate code point")
                        }
                        result.append(Character(scalar))
                    } else {
                        guard let scalar = Unicode.Scalar(codePoint) else {
                            throw error("Invalid Unicode scalar value")
                        }
                        result.append(Character(scalar))
                    }
                default:
                    throw error("Invalid escape sequence '\\(\(escaped))'")
                }
            } else if ch.unicodeScalars.first!.value < 0x20 {
                throw error("Control character in string")
            } else {
                result.append(ch)
                advance()
            }
        }

        throw error("Unterminated string")
    }

    private mutating func parseUnicodeEscape() throws -> UInt32 {
        var hex = ""
        for _ in 0..<4 {
            guard position < input.count else {
                throw error("Unexpected end of input in Unicode escape")
            }
            hex.append(input[position])
            advance()
        }
        guard let value = UInt32(hex, radix: 16) else {
            throw error("Invalid Unicode escape '\\u\(hex)'")
        }
        return value
    }

    private mutating func parseNumber() throws -> JSONNode {
        let startPos = position

        // Optional negative sign
        if peek() == "-" { advance() }

        // Integer part
        guard position < input.count else {
            throw error("Unexpected end of input in number")
        }

        if input[position] == "0" {
            advance()
            // After leading 0, next must not be digit
            if position < input.count && input[position].isNumber {
                throw error("Leading zeros not allowed")
            }
        } else if input[position] >= "1" && input[position] <= "9" {
            while position < input.count && input[position].isNumber {
                advance()
            }
        } else {
            throw error("Invalid number")
        }

        // Fractional part
        if position < input.count && input[position] == "." {
            advance()
            guard position < input.count && input[position].isNumber else {
                throw error("Expected digit after decimal point")
            }
            while position < input.count && input[position].isNumber {
                advance()
            }
        }

        // Exponent part
        if position < input.count && (input[position] == "e" || input[position] == "E") {
            advance()
            if position < input.count && (input[position] == "+" || input[position] == "-") {
                advance()
            }
            guard position < input.count && input[position].isNumber else {
                throw error("Expected digit in exponent")
            }
            while position < input.count && input[position].isNumber {
                advance()
            }
        }

        let numberStr = String(input[startPos..<position])
        guard let value = Double(numberStr) else {
            throw error("Invalid number '\(numberStr)'")
        }
        return .number(value)
    }

    private mutating func parseBool() throws -> JSONNode {
        if matchLiteral("true") {
            return .bool(true)
        } else if matchLiteral("false") {
            return .bool(false)
        } else {
            throw error("Invalid value")
        }
    }

    private mutating func parseNull() throws -> JSONNode {
        if matchLiteral("null") {
            return .null
        } else {
            throw error("Invalid value")
        }
    }

    // MARK: - Helpers

    private func peek() -> Character? {
        guard position < input.count else { return nil }
        return input[position]
    }

    private mutating func advance() {
        if position < input.count {
            if input[position] == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            position += 1
        }
    }

    private mutating func expect(_ ch: Character) throws {
        guard position < input.count else {
            throw error("Expected '\(ch)' but reached end of input")
        }
        guard input[position] == ch else {
            throw error("Expected '\(ch)' but found '\(input[position])'")
        }
        advance()
    }

    private mutating func matchLiteral(_ literal: String) -> Bool {
        let chars = Array(literal)
        guard position + chars.count <= input.count else { return false }
        for (i, ch) in chars.enumerated() {
            if input[position + i] != ch { return false }
        }
        for _ in chars {
            advance()
        }
        return true
    }

    private mutating func skipWhitespace() {
        while position < input.count {
            switch input[position] {
            case " ", "\t", "\n", "\r":
                advance()
            default:
                return
            }
        }
    }

    private func error(_ message: String) -> JSONParseError {
        JSONParseError(message: message, line: line, column: column)
    }
}
