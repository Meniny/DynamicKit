
import Foundation


func withValuePointer<Value, Result>(of value: inout Value, _ body: (UnsafeMutableRawPointer) throws -> Result) throws -> Result {
    
    let kind = Kind(type: Value.self)
    
    switch kind {
    case .struct:
        return try withUnsafePointer(to: &value) { try body($0.mutable.raw) }
    case .class:
        return try withClassValuePointer(of: &value, body)
    case .existential:
        return try withExistentialValuePointer(of: &value, body)
    default:
        throw RuntimeError.couldNotGetPointer(type: Value.self, value: value)
    }
}

func withClassValuePointer<Value, Result>(of value: inout Value, _ body: (UnsafeMutableRawPointer) throws -> Result) throws -> Result {
    return try withUnsafePointer(to: &value) {
        let pointer = $0.withMemoryRebound(to: UnsafeMutableRawPointer.self, capacity: 1){$0.pointee}
        return try body(pointer)
    }
}

func withExistentialValuePointer<Value, Result>(of value: inout Value, _ body: (UnsafeMutableRawPointer) throws -> Result) throws -> Result {
    return try withUnsafePointer(to: &value) {
        let container = $0.withMemoryRebound(to: ExistentialContainer.self, capacity: 1){$0.pointee}
        let info = try metadata(of: container.type)
        if info.kind == .class || info.size > ExistentialContainerBuffer.size() {
            let base = $0.withMemoryRebound(to: UnsafeMutableRawPointer.self, capacity: 1){$0.pointee}
            if info.kind == .struct {
                return try body(base.advanced(by: existentialHeaderSize))
            } else {
                return try body(base)
            }
        } else {
            return try body($0.mutable.raw)
        }
    }
}

var existentialHeaderSize: Int {
    if is64Bit {
        return 16
    } else {
        return 8
    }
}

var is64Bit: Bool {
    return MemoryLayout<Int>.size == 8
}



