
import Foundation

// MARK: Expression parsing

// Workaround for horribly slow Substring.UnicodeScalarView perf
internal struct UnicodeScalarView {
    public typealias Index = String.UnicodeScalarView.Index
    
    internal let characters: String.UnicodeScalarView
    public internal(set) var startIndex: Index
    public internal(set) var endIndex: Index
    
    public init(_ unicodeScalars: String.UnicodeScalarView) {
        characters = unicodeScalars
        startIndex = characters.startIndex
        endIndex = characters.endIndex
    }
    
    public init(_ unicodeScalars: Substring.UnicodeScalarView) {
        self.init(String.UnicodeScalarView(unicodeScalars))
    }
    
    public init(_ string: String) {
        self.init(string.unicodeScalars)
    }
    
    public var first: UnicodeScalar? {
        return isEmpty ? nil : characters[startIndex]
    }
    
    public var isEmpty: Bool {
        return startIndex >= endIndex
    }
    
    public subscript(_ index: Index) -> UnicodeScalar {
        return characters[index]
    }
    
    public func index(after index: Index) -> Index {
        return characters.index(after: index)
    }
    
    public func prefix(upTo index: Index) -> UnicodeScalarView {
        var view = UnicodeScalarView(characters)
        view.startIndex = startIndex
        view.endIndex = index
        return view
    }
    
    public func suffix(from index: Index) -> UnicodeScalarView {
        var view = UnicodeScalarView(characters)
        view.startIndex = index
        view.endIndex = endIndex
        return view
    }
    
    public mutating func popFirst() -> UnicodeScalar? {
        if isEmpty {
            return nil
        }
        let char = characters[startIndex]
        startIndex = characters.index(after: startIndex)
        return char
    }
    
    /// Returns the remaining characters
    internal var unicodeScalars: Substring.UnicodeScalarView {
        return characters[startIndex ..< endIndex]
    }
}

internal typealias _UnicodeScalarView = UnicodeScalarView
internal extension String {
    init(_ unicodeScalarView: _UnicodeScalarView) {
        self.init(unicodeScalarView.unicodeScalars)
    }
}

internal extension Substring.UnicodeScalarView {
    init(_ unicodeScalarView: _UnicodeScalarView) {
        self.init(unicodeScalarView.unicodeScalars)
    }
}

internal extension UnicodeScalarView {
    mutating func scanCharacters(_ matching: (UnicodeScalar) -> Bool) -> String? {
        var index = startIndex
        while index < endIndex {
            if !matching(self[index]) {
                break
            }
            index = self.index(after: index)
        }
        if index > startIndex {
            let string = String(prefix(upTo: index))
            self = suffix(from: index)
            return string
        }
        return nil
    }
    
    mutating func scanCharacter(_ matching: (UnicodeScalar) -> Bool = { _ in true }) -> String? {
        if let c = first, matching(c) {
            self = suffix(from: index(after: startIndex))
            return String(c)
        }
        return nil
    }
    
    mutating func scanCharacter(_ character: UnicodeScalar) -> Bool {
        return scanCharacter({ $0 == character }) != nil
    }
    
    mutating func scanToEndOfToken() -> String? {
        return scanCharacters({
            switch $0 {
            case " ", "\t", "\n", "\r":
                return false
            default:
                return true
            }
        })
    }
    
    mutating func skipWhitespace() -> Bool {
        if let _ = scanCharacters({
            switch $0 {
            case " ", "\t", "\n", "\r":
                return true
            default:
                return false
            }
        }) {
            return true
        }
        return false
    }
    
    mutating func parseDelimiter(_ delimiters: [String]) -> Bool {
        outer: for delimiter in delimiters {
            let start = self
            for char in delimiter.unicodeScalars {
                guard scanCharacter(char) else {
                    self = start
                    continue outer
                }
            }
            self = start
            return true
        }
        return false
    }
    
    mutating func parseNumericLiteral() -> SubExpression? {
        func scanInteger() -> String? {
            return scanCharacters {
                if case "0" ... "9" = $0 {
                    return true
                }
                return false
            }
        }
        
        func scanHex() -> String? {
            return scanCharacters {
                switch $0 {
                case "0" ... "9", "A" ... "F", "a" ... "f":
                    return true
                default:
                    return false
                }
            }
        }
        
        func scanExponent() -> String? {
            let start = self
            if let e = scanCharacter({ $0 == "e" || $0 == "E" }) {
                let sign = scanCharacter({ $0 == "-" || $0 == "+" }) ?? ""
                if let exponent = scanInteger() {
                    return e + sign + exponent
                }
            }
            self = start
            return nil
        }
        
        func scanNumber() -> String? {
            var number: String
            var endOfInt = self
            if let integer = scanInteger() {
                if integer == "0", scanCharacter("x") {
                    return "0x\(scanHex() ?? "")"
                }
                endOfInt = self
                if scanCharacter(".") {
                    guard let fraction = scanInteger() else {
                        self = endOfInt
                        return integer
                    }
                    number = "\(integer).\(fraction)"
                } else {
                    number = integer
                }
            } else if scanCharacter(".") {
                guard let fraction = scanInteger() else {
                    self = endOfInt
                    return nil
                }
                number = ".\(fraction)"
            } else {
                return nil
            }
            if let exponent = scanExponent() {
                number += exponent
            }
            return number
        }
        
        guard let number = scanNumber() else {
            return nil
        }
        guard let value = Double(number) else {
            return .error(.unexpectedToken(number), number)
        }
        return .literal(value)
    }
    
    mutating func parseOperator() -> SubExpression? {
        if var op = scanCharacters({ $0 == "." }) ?? scanCharacters({ $0 == "-" }) {
            if let tail = scanCharacters(Expression.isOperator) {
                op += tail
            }
            return .symbol(.infix(op), [], nil)
        }
        if let op = scanCharacters(Expression.isOperator) ??
            scanCharacter({ "([,".unicodeScalars.contains($0) }) {
            return .symbol(.infix(op), [], nil)
        }
        return nil
    }
    
    mutating func parseIdentifier() -> SubExpression? {
        func scanIdentifier() -> String? {
            var start = self
            var identifier = ""
            if scanCharacter(".") {
                identifier = "."
            } else if let head = scanCharacter(Expression.isIdentifierHead) {
                identifier = head
                start = self
                if scanCharacter(".") {
                    identifier.append(".")
                }
            } else {
                return nil
            }
            while let tail = scanCharacters(Expression.isIdentifier) {
                identifier += tail
                start = self
                if scanCharacter(".") {
                    identifier.append(".")
                }
            }
            if identifier.hasSuffix(".") {
                self = start
                if identifier == "." {
                    return nil
                }
                identifier = String(identifier.unicodeScalars.dropLast())
            } else if scanCharacter("'") {
                identifier.append("'")
            }
            return identifier
        }
        
        guard let identifier = scanIdentifier() else {
            return nil
        }
        return .symbol(.variable(identifier), [], nil)
    }
    
    // Note: this is not actually part of the parser, but is colocated
    // with `parseEscapedIdentifier()` because they should be updated together
    func escapedIdentifier() -> String {
        guard let delimiter = first, "`'\"".unicodeScalars.contains(delimiter) else {
            return String(self)
        }
        var result = String(delimiter)
        var index = self.index(after: startIndex)
        while index != endIndex {
            let char = self[index]
            switch char.value {
            case 0:
                result += "\\0"
            case 9:
                result += "\\t"
            case 10:
                result += "\\n"
            case 13:
                result += "\\r"
            case 0x20 ..< 0x7F,
                 _ where Expression.isOperator(char) || Expression.isIdentifier(char):
                result.append(Character(char))
            default:
                result += "\\u{\(String(format: "%X", char.value))}"
            }
            index = self.index(after: index)
        }
        return result
    }
    
    mutating func parseEscapedIdentifier() -> SubExpression? {
        guard let delimiter = first,
            var string = scanCharacter({ "`'\"".unicodeScalars.contains($0) }) else {
                return nil
        }
        while let part = scanCharacters({ $0 != delimiter && $0 != "\\" }) {
            string += part
            if scanCharacter("\\"), let c = popFirst() {
                switch c {
                case "0":
                    string += "\0"
                case "t":
                    string += "\t"
                case "n":
                    string += "\n"
                case "r":
                    string += "\r"
                case "u" where scanCharacter("{"):
                    let hex = scanCharacters({
                        switch $0 {
                        case "0" ... "9", "A" ... "F", "a" ... "f":
                            return true
                        default:
                            return false
                        }
                    }) ?? ""
                    guard scanCharacter("}") else {
                        guard let junk = scanToEndOfToken() else {
                            return .error(.missingDelimiter("}"), string)
                        }
                        return .error(.unexpectedToken(junk), string)
                    }
                    guard !hex.isEmpty else {
                        return .error(.unexpectedToken("}"), string)
                    }
                    guard let codepoint = Int(hex, radix: 16),
                        let c = UnicodeScalar(codepoint) else {
                            // TODO: better error for invalid codepoint?
                            return .error(.unexpectedToken(hex), string)
                    }
                    string.append(Character(c))
                default:
                    string.append(Character(c))
                }
            }
        }
        guard scanCharacter(delimiter) else {
            return .error(string == String(delimiter) ?
                .unexpectedToken(string) : .missingDelimiter(String(delimiter)), string)
        }
        string.append(Character(delimiter))
        return .symbol(.variable(string), [], nil)
    }
    
    mutating func parseSubExpression(upTo delimiters: [String]) throws -> SubExpression {
        var stack: [SubExpression] = []
        
        func collapseStack(from i: Int) throws {
            guard stack.count > i + 1 else {
                return
            }
            let lhs = stack[i]
            let rhs = stack[i + 1]
            if lhs.isOperand {
                if rhs.isOperand {
                    guard case let .symbol(.postfix(op), args, _) = lhs else {
                        // Cannot follow an operand
                        throw Expression.Error.unexpectedToken("\(rhs)")
                    }
                    // Assume postfix operator was actually an infix operator
                    stack[i] = args[0]
                    stack.insert(.symbol(.infix(op), [], nil), at: i + 1)
                    try collapseStack(from: i)
                } else if case let .symbol(symbol, _, _) = rhs {
                    switch symbol {
                    case _ where stack.count <= i + 2, .postfix:
                        stack[i ... i + 1] = [.symbol(.postfix(symbol.name), [lhs], nil)]
                        try collapseStack(from: 0)
                    default:
                        let rhs = stack[i + 2]
                        if rhs.isOperand {
                            if stack.count > i + 3 {
                                let rhs = stack[i + 3]
                                guard !rhs.isOperand, case let .symbol(.infix(op2), _, _) = rhs,
                                    Expression.operator(symbol.name, takesPrecedenceOver: op2) else {
                                        try collapseStack(from: i + 2)
                                        return
                                }
                            }
                            if symbol.name == ":", case let .symbol(.infix("?"), args, _) = lhs { // ternary
                                stack[i ... i + 2] = [.symbol(.infix("?:"), [args[0], args[1], rhs], nil)]
                            } else {
                                stack[i ... i + 2] = [.symbol(.infix(symbol.name), [lhs, rhs], nil)]
                            }
                            try collapseStack(from: 0)
                        } else if case let .symbol(symbol2, _, _) = rhs {
                            if case .prefix = symbol2 {
                                try collapseStack(from: i + 2)
                            } else if ["+", "/", "*"].contains(symbol.name) { // Assume infix
                                stack[i + 2] = .symbol(.prefix(symbol2.name), [], nil)
                                try collapseStack(from: i + 2)
                            } else { // Assume postfix
                                stack[i + 1] = .symbol(.postfix(symbol.name), [], nil)
                                try collapseStack(from: i)
                            }
                        } else if case let .error(error, _) = rhs {
                            throw error
                        }
                    }
                } else if case let .error(error, _) = rhs {
                    throw error
                }
            } else if case let .symbol(symbol, _, _) = lhs {
                // Treat as prefix operator
                if rhs.isOperand {
                    stack[i ... i + 1] = [.symbol(.prefix(symbol.name), [rhs], nil)]
                    try collapseStack(from: 0)
                } else if case .symbol = rhs {
                    // Nested prefix operator?
                    try collapseStack(from: i + 1)
                } else if case let .error(error, _) = rhs {
                    throw error
                }
            } else if case let .error(error, _) = lhs {
                throw error
            }
        }
        
        func scanArguments(upTo delimiter: Unicode.Scalar) throws -> [SubExpression] {
            var args = [SubExpression]()
            if first != delimiter {
                let delimiters = [",", String(delimiter)]
                repeat {
                    do {
                        try args.append(parseSubExpression(upTo: delimiters))
                    } catch Expression.Error.unexpectedToken("") {
                        if let token = scanCharacter() {
                            throw Expression.Error.unexpectedToken(token)
                        }
                    }
                } while scanCharacter(",")
            }
            guard scanCharacter(delimiter) else {
                throw Expression.Error.missingDelimiter(String(delimiter))
            }
            return args
        }
        
        _ = skipWhitespace()
        var operandPosition = true
        var precededByWhitespace = true
        while !parseDelimiter(delimiters), let expression =
            parseNumericLiteral() ??
                parseIdentifier() ??
                parseOperator() ??
                parseEscapedIdentifier() {
                    // Prepare for next iteration
                    var followedByWhitespace = skipWhitespace() || isEmpty
                    
                    switch expression {
                    case let .symbol(.infix(name), _, _):
                        switch name {
                        case "(":
                            switch stack.last {
                            case let .symbol(.variable(name), _, _)?:
                                let args = try scanArguments(upTo: ")")
                                stack[stack.count - 1] =
                                    .symbol(.function(name, arity: .exactly(args.count)), args, nil)
                            case let last? where last.isOperand:
                                let args = try scanArguments(upTo: ")")
                                stack[stack.count - 1] = .symbol(.infix("()"), [last] + args, nil)
                            default:
                                // TODO: if we make `,` a multifix operator, we can use `scanArguments()` here instead
                                // Alternatively: add .function("()", arity: .any), as with []
                                try stack.append(parseSubExpression(upTo: [")"]))
                                guard scanCharacter(")") else {
                                    throw Expression.Error.missingDelimiter(")")
                                }
                            }
                            operandPosition = false
                            followedByWhitespace = skipWhitespace()
                        case ",":
                            operandPosition = true
                            if let last = stack.last, !last.isOperand, case let .symbol(.infix(op), _, _) = last {
                                // If previous token was an infix operator, convert it to postfix
                                stack[stack.count - 1] = .symbol(.postfix(op), [], nil)
                            }
                            stack.append(expression)
                            operandPosition = true
                            followedByWhitespace = skipWhitespace()
                        case "[":
                            let args = try scanArguments(upTo: "]")
                            switch stack.last {
                            case let .symbol(.variable(name), _, _)?:
                                guard args.count == 1 else {
                                    throw Expression.Error.arityMismatch(.array(name))
                                }
                                stack[stack.count - 1] = .symbol(.array(name), [args[0]], nil)
                            case let last? where last.isOperand:
                                guard args.count == 1 else {
                                    throw Expression.Error.arityMismatch(.infix("[]"))
                                }
                                stack[stack.count - 1] = .symbol(.infix("[]"), [last, args[0]], nil)
                            default:
                                stack.append(.symbol(.function("[]", arity: .exactly(args.count)), args, nil))
                            }
                            operandPosition = false
                            followedByWhitespace = skipWhitespace()
                        default:
                            switch (precededByWhitespace, followedByWhitespace) {
                            case (true, true), (false, false):
                                stack.append(expression)
                            case (true, false):
                                stack.append(.symbol(.prefix(name), [], nil))
                            case (false, true):
                                stack.append(.symbol(.postfix(name), [], nil))
                            }
                            operandPosition = true
                        }
                    case let .symbol(.variable(name), _, _) where !operandPosition:
                        operandPosition = true
                        stack.append(.symbol(.infix(name), [], nil))
                    default:
                        operandPosition = false
                        stack.append(expression)
                    }
                    
                    // Next iteration
                    precededByWhitespace = followedByWhitespace
        }
        // Check for trailing junk
        let start = self
        if !parseDelimiter(delimiters), let junk = scanToEndOfToken() {
            self = start
            throw Expression.Error.unexpectedToken(junk)
        }
        try collapseStack(from: 0)
        switch stack.first {
        case let .error(error, _)?:
            throw error
        case let result?:
            if result.isOperand {
                return result
            }
            throw Expression.Error.unexpectedToken(result.description)
        case nil:
            throw Expression.Error.emptyExpression
        }
    }
}
