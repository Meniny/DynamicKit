
import Foundation


protocol IntegerConvertible {
    func getInt() -> Int
}

extension Int: IntegerConvertible {
    func getInt() -> Int {
        return self
    }
}

extension Int32: IntegerConvertible {
    func getInt() -> Int {
        return Int(self)
    }
}
