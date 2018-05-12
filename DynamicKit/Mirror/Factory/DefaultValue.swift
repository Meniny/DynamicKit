
import Foundation

public protocol DefaultConstructor {
    init()
}

extension Int: DefaultConstructor {}
extension Int8: DefaultConstructor {}
extension Int16: DefaultConstructor {}
extension Int32: DefaultConstructor {}
extension Int64: DefaultConstructor {}
extension UInt: DefaultConstructor {}
extension UInt8: DefaultConstructor {}
extension UInt16: DefaultConstructor {}
extension UInt32: DefaultConstructor {}
extension UInt64: DefaultConstructor {}
extension String: DefaultConstructor {}

extension Bool: DefaultConstructor {}
extension Double: DefaultConstructor {}
extension Decimal: DefaultConstructor {}
extension Float: DefaultConstructor {}
extension Date: DefaultConstructor {}
extension UUID: DefaultConstructor {}

extension Array: DefaultConstructor {}
extension Dictionary: DefaultConstructor {}
extension Set: DefaultConstructor {}


extension Character: DefaultConstructor {
    public init() {
        self = " "
    }
}

