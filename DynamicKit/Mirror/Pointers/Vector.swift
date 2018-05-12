
import Foundation


struct Vector<Element> {
    var element: Element
    mutating func vector(n: IntegerConvertible) -> [Element] {
        return withUnsafePointer(to: &self) {
            $0.withMemoryRebound(to: Element.self, capacity: 1) { start in
                return start.vector(n: n)
            }
        }
    }
}
