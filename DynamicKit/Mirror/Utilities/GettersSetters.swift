
import Foundation


protocol Getters {}
extension Getters {
    static func get(from pointer: UnsafeRawPointer) -> Any {
        return pointer.assumingMemoryBound(to: self).pointee
    }
}

func getters(type: Any.Type) -> Getters.Type {
    let container = ProtocolTypeContainer(type: type, witnessTable: 0)
    return unsafeBitCast(container, to: Getters.Type.self)
}


protocol Setters {}
extension Setters {
    static func set(value: Any, pointer: UnsafeMutableRawPointer) {
        if let value = value as? Self {
            pointer.assumingMemoryBound(to: self).initialize(to: value)
        }
    }
}

func setters(type: Any.Type) -> Setters.Type {
    let container = ProtocolTypeContainer(type: type, witnessTable: 0)
    return unsafeBitCast(container, to: Setters.Type.self)
}

