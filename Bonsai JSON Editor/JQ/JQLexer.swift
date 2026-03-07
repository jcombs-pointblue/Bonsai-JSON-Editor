import Foundation

/// Operators supported in jq expressions
enum JQOperator: String, Sendable {
    case eq = "=="
    case neq = "!="
    case lt = "<"
    case lte = "<="
    case gt = ">"
    case gte = ">="
    case add = "+"
    case sub = "-"
    case mul = "*"
    case div = "/"
    case mod = "%"
}

/// Keywords recognized by the jq lexer
enum JQKeyword: String, Sendable {
    case `if` = "if"
    case then = "then"
    case `else` = "else"
    case elif = "elif"
    case end = "end"
    case reduce = "reduce"
    case `as` = "as"
    case def = "def"
    case `true` = "true"
    case `false` = "false"
    case null = "null"
    case and = "and"
    case or = "or"
    case not = "not"
    case `try` = "try"
    case `catch` = "catch"
}

/// Token types produced by the jq lexer
enum JQToken: Equatable, Sendable {
    case dot
    case dotDot
    case identifier(String)
    case lbracket
    case rbracket
    case lparen
    case rparen
    case lbrace
    case rbrace
    case pipe
    case comma
    case colon
    case semicolon
    case questionMark
    case intLiteral(Int)
    case floatLiteral(Double)
    case stringLiteral(String)
    case keyword(JQKeyword)
    case op(JQOperator)
    case eof
}

/// Errors thrown during jq lexing
struct JQLexError: LocalizedError {
    let message: String
    let position: Int

    var errorDescription: String? {
        "jq syntax error at position \(position): \(message)"
    }
}

/// Tokenizer for jq expressions
struct JQLexer {
    private let input: [Character]
    private var position: Int = 0

    private init(_ string: String) {
        self.input = Array(string)
    }

    /// Tokenize a jq expression string into tokens
    static func tokenize(_ input: String) throws -> [JQToken] {
        var lexer = JQLexer(input)
        var tokens: [JQToken] = []

        while true {
            let token = try lexer.nextToken()
            tokens.append(token)
            if token == .eof { break }
        }

        return tokens
    }

    private mutating func nextToken() throws -> JQToken {
        skipWhitespace()
        guard position < input.count else { return .eof }

        let ch = input[position]

        switch ch {
        case ".":
            advance()
            if position < input.count && input[position] == "." {
                advance()
                return .dotDot
            }
            // Check if this is a field access like .foo
            // If next char is a letter or underscore, it's a field access — return the dot
            return .dot

        case "|": advance(); return .pipe
        case ",": advance(); return .comma
        case ":": advance(); return .colon
        case ";": advance(); return .semicolon
        case "(": advance(); return .lparen
        case ")": advance(); return .rparen
        case "[": advance(); return .lbracket
        case "]": advance(); return .rbracket
        case "{": advance(); return .lbrace
        case "}": advance(); return .rbrace
        case "?":
            advance()
            // Check for ?// (alternative operator) — not implemented in v1
            return .questionMark

        case "+": advance(); return .op(.add)
        case "*": advance(); return .op(.mul)
        case "/":
            advance()
            if position < input.count && input[position] == "/" {
                advance()
                // Alternative operator // — skip for now, treat as two divides
                return .op(.div)
            }
            return .op(.div)
        case "%": advance(); return .op(.mod)

        case "-":
            // Could be subtraction or negative number
            // If preceded by nothing or an operator/punctuation, treat as part of a number
            advance()
            if position < input.count && input[position].isNumber {
                // Look back to determine context — for simplicity, always lex as minus operator
                // The parser will handle unary minus
                position -= 1  // put back the advance
                advance()
                return .op(.sub)
            }
            return .op(.sub)

        case "=":
            advance()
            if position < input.count && input[position] == "=" {
                advance()
                return .op(.eq)
            }
            throw JQLexError(message: "Unexpected '='", position: position - 1)

        case "!":
            advance()
            if position < input.count && input[position] == "=" {
                advance()
                return .op(.neq)
            }
            throw JQLexError(message: "Unexpected '!'", position: position - 1)

        case "<":
            advance()
            if position < input.count && input[position] == "=" {
                advance()
                return .op(.lte)
            }
            return .op(.lt)

        case ">":
            advance()
            if position < input.count && input[position] == "=" {
                advance()
                return .op(.gte)
            }
            return .op(.gt)

        case "\"":
            return try lexString()

        case _ where ch.isNumber:
            return try lexNumber()

        case _ where ch.isLetter || ch == "_":
            return lexIdentifierOrKeyword()

        default:
            throw JQLexError(message: "Unexpected character '\(ch)'", position: position)
        }
    }

    private mutating func lexString() throws -> JQToken {
        advance() // skip opening quote
        var result = ""

        while position < input.count {
            let ch = input[position]
            if ch == "\"" {
                advance()
                return .stringLiteral(result)
            } else if ch == "\\" {
                advance()
                guard position < input.count else {
                    throw JQLexError(message: "Unterminated string escape", position: position)
                }
                let escaped = input[position]
                advance()
                switch escaped {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                default: result.append(escaped)
                }
            } else {
                result.append(ch)
                advance()
            }
        }

        throw JQLexError(message: "Unterminated string", position: position)
    }

    private mutating func lexNumber() throws -> JQToken {
        let start = position
        while position < input.count && input[position].isNumber {
            advance()
        }

        // Check for decimal point
        if position < input.count && input[position] == "." {
            advance()
            while position < input.count && input[position].isNumber {
                advance()
            }
            let numStr = String(input[start..<position])
            guard let value = Double(numStr) else {
                throw JQLexError(message: "Invalid number '\(numStr)'", position: start)
            }
            return .floatLiteral(value)
        }

        let numStr = String(input[start..<position])
        guard let value = Int(numStr) else {
            throw JQLexError(message: "Invalid integer '\(numStr)'", position: start)
        }
        return .intLiteral(value)
    }

    private mutating func lexIdentifierOrKeyword() -> JQToken {
        let start = position
        while position < input.count && (input[position].isLetter || input[position].isNumber || input[position] == "_") {
            advance()
        }

        let word = String(input[start..<position])

        // Check for keywords
        if let kw = JQKeyword(rawValue: word) {
            return .keyword(kw)
        }

        return .identifier(word)
    }

    private mutating func advance() {
        position += 1
    }

    private mutating func skipWhitespace() {
        while position < input.count && (input[position] == " " || input[position] == "\t" || input[position] == "\n" || input[position] == "\r") {
            advance()
        }
    }
}
