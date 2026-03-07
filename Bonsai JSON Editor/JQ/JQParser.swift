import Foundation

/// Errors thrown during jq expression parsing
struct JQParseError: LocalizedError {
    let message: String
    let position: Int?

    var errorDescription: String? {
        if let pos = position {
            return "jq parse error at token \(pos): \(message)"
        }
        return "jq parse error: \(message)"
    }
}

/// Parser that converts jq tokens into a JQExpression AST.
/// Implements a Pratt-style (precedence climbing) recursive descent parser.
struct JQParser {
    private var tokens: [JQToken]
    private var position: Int = 0

    private init(_ tokens: [JQToken]) {
        self.tokens = tokens
    }

    /// Parse tokens into a JQExpression AST
    static func parse(_ tokens: [JQToken]) throws -> JQExpression {
        var parser = JQParser(tokens)
        let expr = try parser.parseExpression()
        if parser.peek() != .eof {
            throw JQParseError(message: "Unexpected token: \(parser.peek())", position: parser.position)
        }
        return expr
    }

    // MARK: - Expression parsing with precedence

    /// Top-level: pipe has lowest precedence
    private mutating func parseExpression() throws -> JQExpression {
        return try parsePipe()
    }

    /// Pipe: expr | expr (right-associative)
    private mutating func parsePipe() throws -> JQExpression {
        var left = try parseComma()

        while peek() == .pipe {
            advance()
            let right = try parseComma()
            left = .pipe(left, right)
        }

        return left
    }

    /// Comma: expr, expr
    private mutating func parseComma() throws -> JQExpression {
        var left = try parseLogicalOr()

        while peek() == .comma {
            // Only consume comma if we're not inside brackets/parens that own it
            advance()
            let right = try parseLogicalOr()
            left = .comma(left, right)
        }

        return left
    }

    /// Logical OR: expr or expr
    private mutating func parseLogicalOr() throws -> JQExpression {
        var left = try parseLogicalAnd()

        while peek() == .keyword(.or) {
            advance()
            let right = try parseLogicalAnd()
            left = .logicalOr(left, right)
        }

        return left
    }

    /// Logical AND: expr and expr
    private mutating func parseLogicalAnd() throws -> JQExpression {
        var left = try parseNot()

        while peek() == .keyword(.and) {
            advance()
            let right = try parseNot()
            left = .logicalAnd(left, right)
        }

        return left
    }

    /// Logical NOT: `not` is a filter in jq (postfix), not a prefix operator.
    /// It's handled as a builtin in parsePrimary. This just forwards to comparison.
    private mutating func parseNot() throws -> JQExpression {
        return try parseComparison()
    }

    /// Comparison: expr == != < <= > >= expr
    private mutating func parseComparison() throws -> JQExpression {
        var left = try parseAddSub()

        while true {
            let op: ComparisonOp
            switch peek() {
            case .op(.eq): op = .eq
            case .op(.neq): op = .neq
            case .op(.lt): op = .lt
            case .op(.lte): op = .lte
            case .op(.gt): op = .gt
            case .op(.gte): op = .gte
            default: return left
            }
            advance()
            let right = try parseAddSub()
            left = .comparison(left, op, right)
        }
    }

    /// Addition/Subtraction: expr + - expr
    private mutating func parseAddSub() throws -> JQExpression {
        var left = try parseMulDiv()

        while true {
            let op: ArithOp
            switch peek() {
            case .op(.add): op = .add
            case .op(.sub): op = .sub
            default: return left
            }
            advance()
            let right = try parseMulDiv()
            left = .arithmetic(left, op, right)
        }
    }

    /// Multiplication/Division: expr * / % expr
    private mutating func parseMulDiv() throws -> JQExpression {
        var left = try parseUnary()

        while true {
            let op: ArithOp
            switch peek() {
            case .op(.mul): op = .mul
            case .op(.div): op = .div
            case .op(.mod): op = .mod
            default: return left
            }
            advance()
            let right = try parseUnary()
            left = .arithmetic(left, op, right)
        }
    }

    /// Unary minus
    private mutating func parseUnary() throws -> JQExpression {
        if peek() == .op(.sub) {
            advance()
            let expr = try parsePostfix()
            return .negate(expr)
        }
        return try parsePostfix()
    }

    /// Postfix: expr[] expr[n] expr.field expr?
    private mutating func parsePostfix() throws -> JQExpression {
        var expr = try parsePrimary()

        while true {
            switch peek() {
            case .lbracket:
                advance()
                if peek() == .rbracket {
                    // .[]
                    advance()
                    let optional = peek() == .questionMark
                    if optional { advance() }
                    expr = .pipe(expr, .iterator(optional: optional))
                } else if let startIdx = tryParseInt() {
                    if peek() == .colon {
                        // .[start:end]
                        advance()
                        let endIdx = tryParseInt()
                        try expect(.rbracket)
                        expr = .pipe(expr, .slice(startIdx, endIdx))
                    } else {
                        // .[n]
                        try expect(.rbracket)
                        expr = .pipe(expr, .index(startIdx))
                    }
                } else if peek() == .colon {
                    // .[:end]
                    advance()
                    let endIdx = tryParseInt()
                    try expect(.rbracket)
                    expr = .pipe(expr, .slice(nil, endIdx))
                } else {
                    // .[expr] — treat as string index
                    let indexExpr = try parseExpression()
                    try expect(.rbracket)
                    // For string keys inside brackets, convert to field access
                    if case .literal(.string(let key)) = indexExpr {
                        expr = .pipe(expr, .field(key, optional: false))
                    } else {
                        // Dynamic index — not fully supported, treat as pipe
                        expr = .pipe(expr, indexExpr)
                    }
                }

            case .dot:
                // Check if next is an identifier (field access)
                let savedPos = position
                advance()
                if case .identifier(let name) = peek() {
                    advance()
                    let optional = peek() == .questionMark
                    if optional { advance() }
                    expr = .pipe(expr, .field(name, optional: optional))
                } else if peek() == .lbracket {
                    // .[...] syntax after pipe
                    position = savedPos
                    break
                } else {
                    position = savedPos
                    return expr
                }

            case .questionMark:
                advance()
                // Convert to optional variant if applicable
                expr = .tryExpr(expr, catch: .literal(.null))

            default:
                return expr
            }
        }
    }

    /// Primary expressions
    private mutating func parsePrimary() throws -> JQExpression {
        switch peek() {
        case .dot:
            advance()
            // Check what follows the dot
            switch peek() {
            case .identifier(let name):
                advance()
                let optional = peek() == .questionMark
                if optional { advance() }
                return .field(name, optional: optional)
            case .lbracket:
                advance()
                if peek() == .rbracket {
                    advance()
                    let optional = peek() == .questionMark
                    if optional { advance() }
                    return .iterator(optional: optional)
                } else if let idx = tryParseInt() {
                    if peek() == .colon {
                        advance()
                        let endIdx = tryParseInt()
                        try expect(.rbracket)
                        return .slice(idx, endIdx)
                    }
                    try expect(.rbracket)
                    return .index(idx)
                } else if peek() == .colon {
                    advance()
                    let endIdx = tryParseInt()
                    try expect(.rbracket)
                    return .slice(nil, endIdx)
                } else {
                    let indexExpr = try parseExpression()
                    try expect(.rbracket)
                    if case .literal(.string(let key)) = indexExpr {
                        return .field(key, optional: false)
                    }
                    return indexExpr
                }
            default:
                return .identity
            }

        case .dotDot:
            advance()
            return .recursive

        case .intLiteral(let n):
            advance()
            return .literal(.number(Double(n)))

        case .floatLiteral(let n):
            advance()
            return .literal(.number(n))

        case .stringLiteral(let s):
            advance()
            return .literal(.string(s))

        case .keyword(.true):
            advance()
            return .literal(.bool(true))

        case .keyword(.false):
            advance()
            return .literal(.bool(false))

        case .keyword(.null):
            advance()
            return .literal(.null)

        case .keyword(.if):
            return try parseIf()

        case .keyword(.try):
            advance()
            let expr = try parsePostfix()
            if peek() == .keyword(.catch) {
                advance()
                let catchExpr = try parsePostfix()
                return .tryExpr(expr, catch: catchExpr)
            }
            return .tryExpr(expr, catch: nil)

        case .keyword(.not):
            advance()
            return .builtin("not", args: [])

        case .lbracket:
            advance()
            if peek() == .rbracket {
                advance()
                return .arrayConstruct(nil)
            }
            let inner = try parseExpression()
            try expect(.rbracket)
            return .arrayConstruct(inner)

        case .lbrace:
            return try parseObjectConstruction()

        case .lparen:
            advance()
            let inner = try parseExpression()
            try expect(.rparen)
            return inner

        case .identifier(let name):
            advance()
            // Check if it's a builtin function call with arguments
            if peek() == .lparen {
                advance()
                var args: [JQExpression] = []
                if peek() != .rparen {
                    args.append(try parseExpression())
                    while peek() == .semicolon {
                        advance()
                        args.append(try parseExpression())
                    }
                }
                try expect(.rparen)
                return .builtin(name, args: args)
            }
            // Zero-argument builtin or identifier
            return .builtin(name, args: [])

        default:
            throw JQParseError(message: "Unexpected token: \(peek())", position: position)
        }
    }

    // MARK: - Compound expressions

    private mutating func parseIf() throws -> JQExpression {
        try expect(.keyword(.if))
        let condition = try parseExpression()
        try expect(.keyword(.then))
        let thenExpr = try parseExpression()

        var elseExpr: JQExpression? = nil
        if peek() == .keyword(.elif) {
            // elif is sugar for else if ... end
            elseExpr = try parseIf()
        } else if peek() == .keyword(.else) {
            advance()
            elseExpr = try parseExpression()
            try expect(.keyword(.end))
        } else {
            try expect(.keyword(.end))
        }

        return .ifThenElse(condition: condition, then: thenExpr, else: elseExpr)
    }

    private mutating func parseObjectConstruction() throws -> JQExpression {
        try expect(.lbrace)
        var pairs: [(key: JQExpression.ObjKey, value: JQExpression)] = []

        if peek() != .rbrace {
            let pair = try parseObjectPair()
            pairs.append(pair)
            while peek() == .comma {
                advance()
                let pair = try parseObjectPair()
                pairs.append(pair)
            }
        }

        try expect(.rbrace)
        return .objectConstruct(pairs)
    }

    private mutating func parseObjectPair() throws -> (key: JQExpression.ObjKey, value: JQExpression) {
        let key: JQExpression.ObjKey

        switch peek() {
        case .identifier(let name):
            advance()
            key = .name(name)
        case .stringLiteral(let s):
            advance()
            key = .name(s)
        case .lparen:
            advance()
            let keyExpr = try parseExpression()
            try expect(.rparen)
            key = .expr(keyExpr)
        default:
            throw JQParseError(message: "Expected object key", position: position)
        }

        if peek() == .colon {
            advance()
            let value = try parseLogicalOr()
            return (key: key, value: value)
        } else {
            // Shorthand {name} is like {name: .name}
            if case .name(let n) = key {
                return (key: key, value: .field(n, optional: false))
            }
            throw JQParseError(message: "Expected ':' in object construction", position: position)
        }
    }

    // MARK: - Helpers

    private func peek() -> JQToken {
        guard position < tokens.count else { return .eof }
        return tokens[position]
    }

    private mutating func advance() {
        position += 1
    }

    private mutating func expect(_ token: JQToken) throws {
        guard peek() == token else {
            throw JQParseError(message: "Expected \(token) but got \(peek())", position: position)
        }
        advance()
    }

    private mutating func tryParseInt() -> Int? {
        if case .intLiteral(let n) = peek() {
            advance()
            return n
        }
        // Handle negative int
        if peek() == .op(.sub) {
            let saved = position
            advance()
            if case .intLiteral(let n) = peek() {
                advance()
                return -n
            }
            position = saved
        }
        return nil
    }
}
