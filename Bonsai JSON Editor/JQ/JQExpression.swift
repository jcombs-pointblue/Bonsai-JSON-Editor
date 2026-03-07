import Foundation

/// Comparison operators used in jq expressions
enum ComparisonOp: Sendable {
    case eq, neq, lt, lte, gt, gte
}

/// Arithmetic operators used in jq expressions
enum ArithOp: Sendable {
    case add, sub, mul, div, mod
}

/// AST for jq expressions
indirect enum JQExpression: Sendable {
    case identity                                           // .
    case recursive                                          // ..
    case field(String, optional: Bool)                      // .foo, .foo?
    case index(Int)                                         // .[0]
    case slice(Int?, Int?)                                  // .[2:5]
    case iterator(optional: Bool)                           // .[]
    case pipe(JQExpression, JQExpression)                   // a | b
    case comma(JQExpression, JQExpression)                  // a, b
    case literal(JSONNode)                                  // 1, "str", true, null
    case arrayConstruct(JQExpression?)                      // [expr] or []
    case objectConstruct([(key: ObjKey, value: JQExpression)])
    case comparison(JQExpression, ComparisonOp, JQExpression)
    case arithmetic(JQExpression, ArithOp, JQExpression)
    case logicalAnd(JQExpression, JQExpression)
    case logicalOr(JQExpression, JQExpression)
    case not(JQExpression)
    case negate(JQExpression)                               // unary minus
    case ifThenElse(condition: JQExpression, then: JQExpression, `else`: JQExpression?)
    case tryExpr(JQExpression, catch: JQExpression?)
    case builtin(String, args: [JQExpression])              // length, keys, etc.
    case funcCall(String, args: [JQExpression])             // user-defined functions

    /// Object key can be an identifier or an expression
    enum ObjKey: Sendable {
        case name(String)
        case expr(JQExpression)
    }
}
