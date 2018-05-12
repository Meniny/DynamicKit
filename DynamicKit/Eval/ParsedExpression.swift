
import Foundation

/// An opaque wrapper for a parsed expression
public struct ParsedExpression: CustomStringConvertible {
    internal let root: SubExpression
    
    /// Returns the pretty-printed expression if it was valid
    /// Otherwise, returns the original (invalid) expression string
    public var description: String { return root.description }
    
    /// All symbols used in the expression
    public var symbols: Set<Expression.Symbol> { return root.symbols }
    
    /// Any error detected during parsing
    public var error: Expression.Error? {
        if case let .error(error, _) = root {
            return error
        }
        return nil
    }
}
