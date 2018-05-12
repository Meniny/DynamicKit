
import Foundation
import Dispatch

/// Immutable wrapper for a parsed expression
/// Reusing the same Expression instance for multiple evaluations is more efficient
/// than creating a new one each time you wish to evaluate an expression string
public final class Expression: CustomStringConvertible {
    internal let root: SubExpression

    /// Evaluator for individual symbols
    public typealias SymbolEvaluator = (_ args: [Double]) throws -> Double

    /// Type representing the arity (number of arguments) accepted by a function
    public enum Arity: ExpressibleByIntegerLiteral, CustomStringConvertible, Equatable {
        public typealias IntegerLiteralType = Int

        /// An exact number of arguments
        case exactly(Int)

        /// A minimum number of arguments
        case atLeast(Int)

        /// Any number of arguments
        public static let any = atLeast(0)

        /// ExpressibleByIntegerLiteral constructor
        public init(integerLiteral value: Int) {
            self = .exactly(value)
        }

        /// The human-readable description of the arity
        public var description: String {
            switch self {
            case let .exactly(value):
                return "\(value) argument\(value == 1 ? "" : "s")"
            case let .atLeast(value):
                return "at least \(value) argument\(value == 1 ? "" : "s")"
            }
        }

        /// Equatable implementation
        /// Note: this works more like a contains() function if
        /// one side a range and the other is an exact value
        /// This allows foo(x) to match foo(...) in a symbols dictionary
        public static func == (lhs: Arity, rhs: Arity) -> Bool {
            switch (lhs, rhs) {
            case let (.exactly(lhs), .exactly(rhs)),
                 let (.atLeast(lhs), .atLeast(rhs)):
                return lhs == rhs
            case let (.atLeast(min), .exactly(value)),
                 let (.exactly(value), .atLeast(min)):
                return value >= min
            }
        }
    }

    /// Symbols that make up an expression
    public enum Symbol: CustomStringConvertible, Hashable {
        /// A named variable
        case variable(String)

        /// An infix operator
        case infix(String)

        /// A prefix operator
        case prefix(String)

        /// A postfix operator
        case postfix(String)

        /// A function accepting a number of arguments specified by `arity`
        case function(String, arity: Arity)

        /// A array of values accessed by index
        case array(String)

        /// The symbol name
        public var name: String {
            switch self {
            case let .variable(name),
                 let .infix(name),
                 let .prefix(name),
                 let .postfix(name),
                 let .function(name, _),
                 let .array(name):
                return name
            }
        }

        /// Printable version of the symbol name
        var escapedName: String {
            return UnicodeScalarView(name).escapedIdentifier()
        }

        /// The human-readable description of the symbol
        public var description: String {
            switch self {
            case .variable:
                return "variable \(escapedName)"
            case .infix("?:"):
                return "ternary operator \(escapedName)"
            case .infix("[]"):
                return "subscript operator \(escapedName)"
            case .infix("()"):
                return "function call operator \(escapedName)"
            case .infix:
                return "infix operator \(escapedName)"
            case .prefix:
                return "prefix operator \(escapedName)"
            case .postfix:
                return "postfix operator \(escapedName)"
            case .function:
                return "function \(escapedName)()"
            case .array:
                return "array \(escapedName)[]"
            }
        }

        /// Required by the Hashable protocol
        public var hashValue: Int {
            return name.hashValue
        }

        /// Equatable implementation
        public static func == (lhs: Symbol, rhs: Symbol) -> Bool {
            switch (lhs, rhs) {
            case let (.variable(lhs), .variable(rhs)),
                 let (.infix(lhs), .infix(rhs)),
                 let (.prefix(lhs), .prefix(rhs)),
                 let (.postfix(lhs), .postfix(rhs)),
                 let (.array(lhs), .array(rhs)):
                return lhs == rhs
            case let (.function(lhs), .function(rhs)):
                return lhs == rhs
            case (.variable, _),
                 (.infix, _),
                 (.prefix, _),
                 (.postfix, _),
                 (.function, _),
                 (.array, _):
                return false
            }
        }
    }

    /// Runtime error when parsing or evaluating an expression
    public enum Error: Swift.Error, CustomStringConvertible, Equatable {
        /// An application-specific error
        case message(String)

        /// The parser encountered a sequence of characters it didn't recognize
        case unexpectedToken(String)

        /// The parser expected to find a delimiter (e.g. closing paren) but didn't
        case missingDelimiter(String)

        /// The specified constant, operator or function was not recognized
        case undefinedSymbol(Symbol)

        /// A function was called with the wrong number of arguments (arity)
        case arityMismatch(Symbol)

        /// An array was accessed with an index outside the valid range
        case arrayBounds(Symbol, Double)

        /// Empty expression
        public static let emptyExpression = unexpectedToken("")

        /// The human-readable description of the error
        public var description: String {
            switch self {
            case let .message(message):
                return message
            case .emptyExpression:
                return "Empty expression"
            case let .unexpectedToken(string):
                return "Unexpected token `\(string)`"
            case let .missingDelimiter(string):
                return "Missing `\(string)`"
            case let .undefinedSymbol(symbol):
                return "Undefined \(symbol)"
            case let .arityMismatch(symbol):
                let arity: Arity
                switch symbol {
                case let .function(_, requiredArity):
                    arity = requiredArity
                case .infix("()"):
                    arity = .atLeast(1)
                case .array, .infix("[]"):
                    arity = 1
                case .infix("?:"):
                    arity = 3
                case .infix:
                    arity = 2
                case .postfix, .prefix:
                    arity = 1
                case .variable:
                    arity = 0
                }
                let description = symbol.description
                return "\(description.prefix(1).uppercased())\(description.dropFirst()) expects \(arity)"
            case let .arrayBounds(symbol, index):
                return "Index \(Expression.stringify(index)) out of bounds for \(symbol)"
            }
        }

        /// Equatable implementation
        public static func == (lhs: Error, rhs: Error) -> Bool {
            switch (lhs, rhs) {
            case let (.message(lhs), .message(rhs)),
                 let (.unexpectedToken(lhs), .unexpectedToken(rhs)),
                 let (.missingDelimiter(lhs), .missingDelimiter(rhs)):
                return lhs == rhs
            case let (.undefinedSymbol(lhs), .undefinedSymbol(rhs)),
                 let (.arityMismatch(lhs), .arityMismatch(rhs)):
                return lhs == rhs
            case let (.arrayBounds(lhs), .arrayBounds(rhs)):
                return lhs == rhs
            case (.message, _),
                 (.unexpectedToken, _),
                 (.missingDelimiter, _),
                 (.undefinedSymbol, _),
                 (.arityMismatch, _),
                 (.arrayBounds, _):
                return false
            }
        }
    }

    /// Options for configuring an expression
    public struct Options: OptionSet {
        /// Disable optimizations such as constant substitution
        public static let noOptimize = Options(rawValue: 1 << 1)

        /// Enable standard boolean operators and constants
        public static let boolSymbols = Options(rawValue: 1 << 2)

        /// Assume all functions and operators in `symbols` are "pure", i.e.
        /// they have no side effects, and always produce the same output
        /// for a given set of arguments
        public static let pureSymbols = Options(rawValue: 1 << 3)

        /// Packed bitfield of options
        public let rawValue: Int

        /// Designated initializer
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    /// Creates an Expression object from a string
    /// Optionally accepts some or all of:
    /// - A set of options for configuring expression behavior
    /// - A dictionary of constants for simple static values
    /// - A dictionary of arrays for static collections of related values
    /// - A dictionary of symbols, for implementing custom functions and operators
    public convenience init(
        _ expression: String,
        options: Options = [],
        constants: [String: Double] = [:],
        arrays: [String: [Double]] = [:],
        symbols: [Symbol: SymbolEvaluator] = [:]
    ) {
        self.init(
            Expression.parse(expression),
            options: options,
            constants: constants,
            arrays: arrays,
            symbols: symbols
        )
    }

    /// Alternative constructor that accepts a pre-parsed expression
    public convenience init(
        _ expression: ParsedExpression,
        options: Options = [],
        constants: [String: Double] = [:],
        arrays: [String: [Double]] = [:],
        symbols: [Symbol: SymbolEvaluator] = [:]
    ) {
        // Options
        let boolSymbols = options.contains(.boolSymbols) ? Expression.boolSymbols : [:]
        let shouldOptimize = !options.contains(.noOptimize)
        let pureSymbols = options.contains(.pureSymbols)

        // Evaluators
        func symbolEvaluator(for symbol: Symbol) -> SymbolEvaluator? {
            if let fn = symbols[symbol] {
                return fn
            } else if boolSymbols.isEmpty, case .infix("?:") = symbol,
                let lhs = symbols[.infix("?")], let rhs = symbols[.infix(":")] {
                // TODO: get rid of this special case? - it's unlikely that it's used by anyone
                return { args in try rhs([lhs([args[0], args[1]]), args[2]]) }
            }
            return nil
        }
        func pureEvaluator(for symbol: Symbol) -> SymbolEvaluator? {
            switch symbol {
            case let .variable(name):
                if let constant = constants[name] {
                    return { _ in constant }
                }
            case let .array(name):
                if let array = arrays[name] {
                    return { args in
                        guard let index = Int(exactly: floor(args[0])),
                            array.indices.contains(index) else {
                            throw Error.arrayBounds(symbol, args[0])
                        }
                        return array[index]
                    }
                }
            default:
                if let fn = symbolEvaluator(for: symbol) {
                    return fn
                }
            }
            guard let fn = Expression.mathSymbols[symbol] ?? boolSymbols[symbol] else {
                if case let .function(name, _) = symbol {
                    for case let .function(_name, arity) in symbols.keys where name == _name {
                        return { _ in throw Error.arityMismatch(.function(name, arity: arity)) }
                    }
                }
                return Expression.errorEvaluator(for: symbol)
            }
            return fn
        }

        self.init(
            expression,
            impureSymbols: { symbol in
                switch symbol {
                case let .variable(name):
                    if constants[name] == nil, let fn = symbols[symbol] {
                        return fn
                    }
                case let .array(name):
                    if arrays[name] == nil, let fn = symbols[symbol] {
                        return fn
                    }
                default:
                    if !pureSymbols, let fn = symbolEvaluator(for: symbol) {
                        return fn
                    }
                }
                return shouldOptimize ? nil : pureEvaluator(for: symbol)
            },
            pureSymbols: pureEvaluator
        )
    }

    /// Alternative constructor for advanced usage
    /// Allows for dynamic symbol lookup or generation without any performance overhead
    /// Note that both math and boolean symbols are enabled by default - to disable them
    /// return `{ _ in throw Expression.Error.undefinedSymbol(symbol) }` from your lookup function
    public init(
        _ expression: ParsedExpression,
        impureSymbols: (Symbol) -> SymbolEvaluator?,
        pureSymbols: (Symbol) -> SymbolEvaluator? = { _ in nil }
    ) {
        root = expression.root.optimized(
            withImpureSymbols: impureSymbols,
            pureSymbols: {
                if let fn = pureSymbols($0) ?? Expression.mathSymbols[$0] ?? Expression.boolSymbols[$0] {
                    return fn
                }
                if case let .function(name, _) = $0 {
                    for i in 0 ... 10 {
                        let symbol = Symbol.function(name, arity: .exactly(i))
                        if impureSymbols(symbol) ?? pureSymbols(symbol) != nil {
                            return { _ in throw Error.arityMismatch(symbol) }
                        }
                    }
                }
                return Expression.errorEvaluator(for: $0)
            }
        )
    }

    /// Alternative constructor with only pure symbols
    public convenience init(_ expression: ParsedExpression, pureSymbols: (Symbol) -> SymbolEvaluator?) {
        self.init(expression, impureSymbols: { _ in nil }, pureSymbols: pureSymbols)
    }

    /// Verify that the string is a valid identifier
    public static func isValidIdentifier(_ string: String) -> Bool {
        var characters = UnicodeScalarView(string)
        switch characters.parseIdentifier() ?? characters.parseEscapedIdentifier() {
        case .symbol(.variable, _, _)?:
            return characters.isEmpty
        default:
            return false
        }
    }

    /// Verify that the string is a valid operator
    public static func isValidOperator(_ string: String) -> Bool {
        var characters = UnicodeScalarView(string)
        guard case let .symbol(symbol, _, _)? = characters.parseOperator(),
            case let .infix(name) = symbol, name != "(", name != "[" else {
            return false
        }
        return characters.isEmpty
    }

    internal static var cache = [String: SubExpression]()
    internal static let queue = DispatchQueue(label: "com.Expression")

    // For testing
    static func isCached(_ expression: String) -> Bool {
        return queue.sync { cache[expression] != nil }
    }

    /// Parse an expression and optionally cache it for future use.
    /// Returns an opaque struct that cannot be evaluated but can be queried
    /// for symbols or used to construct an executable Expression instance
    public static func parse(_ expression: String, usingCache: Bool = true) -> ParsedExpression {
        // Check cache
        if usingCache {
            var cachedExpression: SubExpression?
            queue.sync { cachedExpression = cache[expression] }
            if let subexpression = cachedExpression {
                return ParsedExpression(root: subexpression)
            }
        }

        // Parse
        var characters = Substring.UnicodeScalarView(expression.unicodeScalars)
        let parsedExpression = parse(&characters)

        // Store
        if usingCache {
            queue.sync { cache[expression] = parsedExpression.root }
        }
        return parsedExpression
    }

    /// Parse an expression directly from the provided UnicodeScalarView,
    /// stopping when it reaches a token matching the `delimiter` string.
    /// This is convenient if you wish to parse expressions that are nested
    /// inside another string, e.g. for implementing string interpolation.
    /// If no delimiter string is specified, the method will throw an error
    /// if it encounters an unexpected token, but won't consume it
    public static func parse(
        _ input: inout Substring.UnicodeScalarView,
        upTo delimiters: String...
    ) -> ParsedExpression {
        var unicodeScalarView = UnicodeScalarView(input)
        let start = unicodeScalarView
        var subexpression: SubExpression
        do {
            subexpression = try unicodeScalarView.parseSubExpression(upTo: delimiters)
        } catch {
            let expression = String(start.prefix(upTo: unicodeScalarView.startIndex))
            subexpression = .error(error as! Error, expression)
        }
        input = Substring.UnicodeScalarView(unicodeScalarView)
        return ParsedExpression(root: subexpression)
    }

    /// Clear the expression cache (useful for testing, or in low memory situations)
    public static func clearCache(for expression: String? = nil) {
        queue.sync {
            if let expression = expression {
                cache.removeValue(forKey: expression)
            } else {
                cache.removeAll()
            }
        }
    }

    /// Returns the optmized, pretty-printed expression if it was valid
    /// Otherwise, returns the original (invalid) expression string
    public var description: String { return root.description }

    /// All symbols used in the expression
    public var symbols: Set<Symbol> { return root.symbols }

    /// Evaluate the expression
    public func evaluate() throws -> Double {
        return try root.evaluate()
    }

    /// Standard math symbols
    public static let mathSymbols: [Symbol: SymbolEvaluator] = {
        var symbols: [Symbol: SymbolEvaluator] = [:]

        // constants
        symbols[.variable("pi")] = { _ in .pi }

        // infix operators
        symbols[.infix("+")] = { $0[0] + $0[1] }
        symbols[.infix("-")] = { $0[0] - $0[1] }
        symbols[.infix("*")] = { $0[0] * $0[1] }
        symbols[.infix("/")] = { $0[0] / $0[1] }
        symbols[.infix("%")] = { fmod($0[0], $0[1]) }

        // prefix operators
        symbols[.prefix("-")] = { -$0[0] }

        // functions - arity 1
        symbols[.function("sqrt", arity: 1)] = { sqrt($0[0]) }
        symbols[.function("floor", arity: 1)] = { floor($0[0]) }
        symbols[.function("ceil", arity: 1)] = { ceil($0[0]) }
        symbols[.function("round", arity: 1)] = { round($0[0]) }
        symbols[.function("cos", arity: 1)] = { cos($0[0]) }
        symbols[.function("acos", arity: 1)] = { acos($0[0]) }
        symbols[.function("sin", arity: 1)] = { sin($0[0]) }
        symbols[.function("asin", arity: 1)] = { asin($0[0]) }
        symbols[.function("tan", arity: 1)] = { tan($0[0]) }
        symbols[.function("atan", arity: 1)] = { atan($0[0]) }
        symbols[.function("abs", arity: 1)] = { abs($0[0]) }

        // functions - arity 2
        symbols[.function("pow", arity: 2)] = { pow($0[0], $0[1]) }
        symbols[.function("atan2", arity: 2)] = { atan2($0[0], $0[1]) }
        symbols[.function("mod", arity: 2)] = { fmod($0[0], $0[1]) }

        // functions - variadic
        symbols[.function("max", arity: .atLeast(2))] = { $0.reduce($0[0]) { max($0, $1) } }
        symbols[.function("min", arity: .atLeast(2))] = { $0.reduce($0[0]) { min($0, $1) } }

        return symbols
    }()

    /// Standard boolean symbols
    public static let boolSymbols: [Symbol: SymbolEvaluator] = {
        var symbols: [Symbol: SymbolEvaluator] = [:]

        // boolean constants
        symbols[.variable("true")] = { _ in 1 }
        symbols[.variable("false")] = { _ in 0 }

        // boolean infix operators
        symbols[.infix("==")] = { (args: [Double]) -> Double in args[0] == args[1] ? 1 : 0 }
        symbols[.infix("!=")] = { (args: [Double]) -> Double in args[0] != args[1] ? 1 : 0 }
        symbols[.infix(">")] = { (args: [Double]) -> Double in args[0] > args[1] ? 1 : 0 }
        symbols[.infix(">=")] = { (args: [Double]) -> Double in args[0] >= args[1] ? 1 : 0 }
        symbols[.infix("<")] = { (args: [Double]) -> Double in args[0] < args[1] ? 1 : 0 }
        symbols[.infix("<=")] = { (args: [Double]) -> Double in args[0] <= args[1] ? 1 : 0 }
        symbols[.infix("&&")] = { (args: [Double]) -> Double in args[0] != 0 && args[1] != 0 ? 1 : 0 }
        symbols[.infix("||")] = { (args: [Double]) -> Double in args[0] != 0 || args[1] != 0 ? 1 : 0 }

        // boolean prefix operators
        symbols[.prefix("!")] = { (args: [Double]) -> Double in args[0] == 0 ? 1 : 0 }

        // ternary operator
        symbols[.infix("?:")] = { (args: [Double]) -> Double in
            if args.count == 3 {
                return args[0] != 0 ? args[1] : args[2]
            }
            return args[0] != 0 ? args[0] : args[1]
        }

        return symbols
    }()
}

// MARK: Internal API

internal extension Expression {
    // Fallback evaluator for when symbol is not found
    static func errorEvaluator(for symbol: Symbol) -> SymbolEvaluator {
        switch symbol {
        case .infix(","), .infix("[]"), .function("[]", _), .infix("()"):
            return { _ in throw Error.unexpectedToken(String(symbol.name.prefix(1))) }
        case let .function(called, arity):
            let keys = Set(mathSymbols.keys).union(boolSymbols.keys)
            for case let .function(name, expected) in keys where name == called && arity != expected {
                return { _ in throw Error.arityMismatch(.function(called, arity: expected)) }
            }
            fallthrough
        default:
            return { _ in throw Error.undefinedSymbol(symbol) }
        }
    }
}

// MARK: Private API

internal extension Expression {
    static func stringify(_ number: Double) -> String {
        if let int = Int64(exactly: number) {
            return "\(int)"
        }
        return "\(number)"
    }
    
    // https://github.com/apple/swift-evolution/blob/master/proposals/0077-operator-precedence.md
    static let operatorPrecedence: [String: (precedence: Int, isRightAssociative: Bool)] = {
        var precedences = [
            "[]": 100,
            "<<": 2, ">>": 2, ">>>": 2, // bitshift
            "*": 1, "/": 1, "%": 1, "&": 1, // multiplication
            // +, -, |, ^, etc: 0 (also the default)
            "..": -1, "...": -1, "..<": -1, // range formation
            "is": -2, "as": -2, "isa": -2, // casting
            "??": -3, "?:": -3, // null-coalescing
            // comparison: -4
            "&&": -5, "and": -5, // and
            "||": -6, "or": -6, // or
            "?": -7, ":": -7, // ternary
            // assignment: -8
            ",": -100,
            ].mapValues { ($0, false) }
        let comparisonOperators = [
            "<", "<=", ">=", ">",
            "==", "!=", "<>", "===", "!==",
            "lt", "le", "lte", "gt", "ge", "gte", "eq", "ne",
            ]
        for op in comparisonOperators {
            precedences[op] = (-4, true)
        }
        let assignmentOperators = [
            "=", "*=", "/=", "%=", "+=", "-=",
            "<<=", ">>=", "&=", "^=", "|=", ":=",
            ]
        for op in assignmentOperators {
            precedences[op] = (-8, true)
        }
        return precedences
    }()
    
    static func `operator`(_ lhs: String, takesPrecedenceOver rhs: String) -> Bool {
        let (p1, rightAssociative) = operatorPrecedence[lhs] ?? (0, false)
        let (p2, _) = operatorPrecedence[rhs] ?? (0, false)
        if p1 == p2 {
            return !rightAssociative
        }
        return p1 > p2
    }
    
    static func isOperator(_ char: UnicodeScalar) -> Bool {
        // Strangely, this is faster than switching on value
        if "/=­+!*%<>&|^~?:".unicodeScalars.contains(char) {
            return true
        }
        switch char.value {
        case 0x00A1 ... 0x00A7,
             0x00A9, 0x00AB, 0x00AC, 0x00AE,
             0x00B0 ... 0x00B1,
             0x00B6, 0x00BB, 0x00BF, 0x00D7, 0x00F7,
             0x2016 ... 0x2017,
             0x2020 ... 0x2027,
             0x2030 ... 0x203E,
             0x2041 ... 0x2053,
             0x2055 ... 0x205E,
             0x2190 ... 0x23FF,
             0x2500 ... 0x2775,
             0x2794 ... 0x2BFF,
             0x2E00 ... 0x2E7F,
             0x3001 ... 0x3003,
             0x3008 ... 0x3030:
            return true
        default:
            return false
        }
    }
    
    static func isIdentifierHead(_ c: UnicodeScalar) -> Bool {
        switch c.value {
        case 0x5F, 0x23, 0x24, 0x40, // _ # $ @
        0x41 ... 0x5A, // A-Z
        0x61 ... 0x7A, // a-z
        0x00A8, 0x00AA, 0x00AD, 0x00AF,
        0x00B2 ... 0x00B5,
        0x00B7 ... 0x00BA,
        0x00BC ... 0x00BE,
        0x00C0 ... 0x00D6,
        0x00D8 ... 0x00F6,
        0x00F8 ... 0x00FF,
        0x0100 ... 0x02FF,
        0x0370 ... 0x167F,
        0x1681 ... 0x180D,
        0x180F ... 0x1DBF,
        0x1E00 ... 0x1FFF,
        0x200B ... 0x200D,
        0x202A ... 0x202E,
        0x203F ... 0x2040,
        0x2054,
        0x2060 ... 0x206F,
        0x2070 ... 0x20CF,
        0x2100 ... 0x218F,
        0x2460 ... 0x24FF,
        0x2776 ... 0x2793,
        0x2C00 ... 0x2DFF,
        0x2E80 ... 0x2FFF,
        0x3004 ... 0x3007,
        0x3021 ... 0x302F,
        0x3031 ... 0x303F,
        0x3040 ... 0xD7FF,
        0xF900 ... 0xFD3D,
        0xFD40 ... 0xFDCF,
        0xFDF0 ... 0xFE1F,
        0xFE30 ... 0xFE44,
        0xFE47 ... 0xFFFD,
        0x10000 ... 0x1FFFD,
        0x20000 ... 0x2FFFD,
        0x30000 ... 0x3FFFD,
        0x40000 ... 0x4FFFD,
        0x50000 ... 0x5FFFD,
        0x60000 ... 0x6FFFD,
        0x70000 ... 0x7FFFD,
        0x80000 ... 0x8FFFD,
        0x90000 ... 0x9FFFD,
        0xA0000 ... 0xAFFFD,
        0xB0000 ... 0xBFFFD,
        0xC0000 ... 0xCFFFD,
        0xD0000 ... 0xDFFFD,
        0xE0000 ... 0xEFFFD:
            return true
        default:
            return false
        }
    }
    
    static func isIdentifier(_ c: UnicodeScalar) -> Bool {
        switch c.value {
        case 0x30 ... 0x39, // 0-9
        0x0300 ... 0x036F,
        0x1DC0 ... 0x1DFF,
        0x20D0 ... 0x20FF,
        0xFE20 ... 0xFE2F:
            return true
        default:
            return isIdentifierHead(c)
        }
    }
}
