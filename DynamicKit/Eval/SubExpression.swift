
import Foundation

// The internal expression implementation
internal enum SubExpression: CustomStringConvertible {
    case literal(Double)
    case symbol(Expression.Symbol, [SubExpression], Expression.SymbolEvaluator?)
    case error(Expression.Error, String)
    
    var isOperand: Bool {
        switch self {
        case let .symbol(symbol, args, _) where args.isEmpty:
            switch symbol {
            case .infix, .prefix, .postfix:
                return false
            default:
                return true
            }
        case .symbol, .literal:
            return true
        case .error:
            return false
        }
    }
    
    func evaluate() throws -> Double {
        switch self {
        case let .literal(value):
            return value
        case let .symbol(symbol, args, fn):
            guard let fn = fn else { throw Expression.Error.undefinedSymbol(symbol) }
            return try fn(args.map { try $0.evaluate() })
        case let .error(error, _):
            throw error
        }
    }
    
    var description: String {
        func arguments(_ args: [SubExpression]) -> String {
            return args.map {
                if case .symbol(.infix(","), _, _) = $0 {
                    return "(\($0))"
                }
                return $0.description
                }.joined(separator: ", ")
        }
        switch self {
        case let .literal(value):
            return Expression.stringify(value)
        case let .symbol(symbol, args, _):
            guard isOperand else {
                return symbol.escapedName
            }
            func needsSeparation(_ lhs: String, _ rhs: String) -> Bool {
                let lhs = lhs.unicodeScalars.last!, rhs = rhs.unicodeScalars.first!
                return lhs == "." || (Expression.isOperator(lhs) || lhs == "-")
                    == (Expression.isOperator(rhs) || rhs == "-")
            }
            switch symbol {
            case let .prefix(name):
                let arg = args[0]
                let description = "\(arg)"
                switch arg {
                case .symbol(.infix, _, _), .symbol(.postfix, _, _), .error,
                     .symbol where needsSeparation(name, description):
                    return "\(symbol.escapedName)(\(description))" // Parens required
                case .symbol, .literal:
                    return "\(symbol.escapedName)\(description)" // No parens needed
                }
            case let .postfix(name):
                let arg = args[0]
                let description = "\(arg)"
                switch arg {
                case .symbol(.infix, _, _), .symbol(.postfix, _, _), .error,
                     .symbol where needsSeparation(description, name):
                    return "(\(description))\(symbol.escapedName)" // Parens required
                case .symbol, .literal:
                    return "\(description)\(symbol.escapedName)" // No parens needed
                }
            case .infix(","):
                return "\(args[0]), \(args[1])"
            case .infix("?:") where args.count == 3:
                return "\(args[0]) ? \(args[1]) : \(args[2])"
            case .infix("[]"):
                return "\(args[0])[\(args[1])]"
            case let .infix(name):
                let lhs = args[0]
                let lhsDescription: String
                switch lhs {
                case let .symbol(.infix(opName), _, _)
                    where !Expression.operator(opName, takesPrecedenceOver: name):
                    lhsDescription = "(\(lhs))"
                default:
                    lhsDescription = "\(lhs)"
                }
                let rhs = args[1]
                let rhsDescription: String
                switch rhs {
                case let .symbol(.infix(opName), _, _)
                    where Expression.operator(name, takesPrecedenceOver: opName):
                    rhsDescription = "(\(rhs))"
                default:
                    rhsDescription = "\(rhs)"
                }
                return "\(lhsDescription) \(symbol.escapedName) \(rhsDescription)"
            case .variable:
                return symbol.escapedName
            case .function("[]", _):
                return "[\(arguments(args))]"
            case .function:
                return "\(symbol.escapedName)(\(arguments(args)))"
            case .array:
                return "\(symbol.escapedName)[\(arguments(args))]"
            }
        case let .error(_, expression):
            return expression
        }
    }
    
    var symbols: Set<Expression.Symbol> {
        switch self {
        case .literal, .error:
            return []
        case let .symbol(symbol, subexpressions, _):
            var symbols = Set([symbol])
            for subexpression in subexpressions {
                symbols.formUnion(subexpression.symbols)
            }
            return symbols
        }
    }
    
    func optimized(
        withImpureSymbols impureSymbols: (Expression.Symbol) -> Expression.SymbolEvaluator?,
        pureSymbols: (Expression.Symbol) -> Expression.SymbolEvaluator
        ) -> SubExpression {
        guard case .symbol(let symbol, var args, _) = self else {
            return self
        }
        args = args.map {
            $0.optimized(withImpureSymbols: impureSymbols, pureSymbols: pureSymbols)
        }
        if let fn = impureSymbols(symbol) {
            return .symbol(symbol, args, fn)
        }
        let fn = pureSymbols(symbol)
        var argValues = [Double]()
        for arg in args {
            guard case let .literal(value) = arg else {
                return .symbol(symbol, args, fn)
            }
            argValues.append(value)
        }
        guard let result = try? fn(argValues) else {
            return .symbol(symbol, args, fn)
        }
        return .literal(result)
    }
}
