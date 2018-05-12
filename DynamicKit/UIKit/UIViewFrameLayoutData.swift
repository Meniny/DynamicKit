
import Foundation
#if os(iOS)
import UIKit

internal class UIViewFrameLayoutData: NSObject {
    internal weak var view: UIView!
    internal var inProgress = Set<String>()
    
    func computedValue(forKey key: String) throws -> Double {
        if inProgress.contains(key) {
            throw Expression.Error.message("Circular reference: \(key) depends on itself")
        }
        defer { inProgress.remove(key) }
        inProgress.insert(key)
        
        if let expression = props[key] {
            return try expression.evaluate()
        }
        switch key {
        case "right":
            return try computedValue(forKey: "left") + computedValue(forKey: "width")
        case "bottom":
            return try computedValue(forKey: "top") + computedValue(forKey: "height")
        default:
            throw Expression.Error.undefinedSymbol(.variable(key))
        }
    }
    
    internal func common(_ symbol: Expression.Symbol) -> Expression.SymbolEvaluator? {
        switch symbol {
        case .variable("auto"):
            return { _ in throw Expression.Error.message("`auto` can only be used for width or height") }
        case let .variable(name):
            let parts = name.components(separatedBy: ".")
            if parts.count == 2 {
                return { [unowned self] _ in
                    if let sublayout = self.view.window?.subview(forKey: parts[0])?.layout {
                        return try sublayout.computedValue(forKey: parts[1])
                    }
                    throw Expression.Error.message("No view found for key `\(parts[0])`")
                }
            }
            return { [unowned self] _ in
                try self.computedValue(forKey: parts[0])
            }
        default:
            return nil
        }
    }
    
    var key: String?
    var left: String? {
        didSet {
            props["left"] = Expression(
                Expression.parse(left ?? "0"),
                impureSymbols: { symbol in
                    switch symbol {
                    case .postfix("%"):
                        return { [unowned self] args in
                            self.view.superview.map { Double($0.frame.width) / 100 * args[0] } ?? 0
                        }
                    default:
                        return self.common(symbol)
                    }
            }
            )
        }
    }
    
    var top: String? {
        didSet {
            props["top"] = Expression(
                Expression.parse(top ?? "0"),
                impureSymbols: { symbol in
                    switch symbol {
                    case .postfix("%"):
                        return { [unowned self] args in
                            self.view.superview.map { Double($0.frame.height) / 100 * args[0] } ?? 0
                        }
                    default:
                        return self.common(symbol)
                    }
            }
            )
        }
    }
    
    var width: String? {
        didSet {
            props["width"] = Expression(
                Expression.parse(width ?? "100%"),
                impureSymbols: { symbol in
                    switch symbol {
                    case .postfix("%"):
                        return { [unowned self] args in
                            self.view.superview.map { Double($0.frame.width) / 100 * args[0] } ?? 0
                        }
                    case .variable("auto"):
                        return { [unowned self] _ in
                            self.view.superview.map { superview in
                                Double(self.view.systemLayoutSizeFitting(superview.frame.size).width)
                                } ?? 0
                        }
                    default:
                        return self.common(symbol)
                    }
            }
            )
        }
    }
    
    var height: String? {
        didSet {
            props["height"] = Expression(
                Expression.parse(height ?? "100%"),
                impureSymbols: { symbol in
                    switch symbol {
                    case .postfix("%"):
                        return { [unowned self] args in
                            self.view.superview.map { Double($0.frame.height) / 100 * args[0] } ?? 0
                        }
                    case .variable("auto"):
                        return { [unowned self] _ in
                            try self.view.superview.map { superview in
                                var size = superview.frame.size
                                size.width = CGFloat(try self.computedValue(forKey: "width"))
                                return Double(self.view.systemLayoutSizeFitting(size).height)
                                } ?? 0
                        }
                    default:
                        return self.common(symbol)
                    }
            }
            )
        }
    }
    
    internal var props: [String: Expression] = [:]
    
    init(_ view: UIView) {
        self.view = view
        left = nil
        top = nil
        width = nil
        height = nil
    }
}
#endif
