
import Foundation



struct RelativeVectorPointer<Offset: IntegerConvertible, Pointee> {
    var offset: Offset
    mutating func vector(metadata: UnsafePointer<Int>, n: IntegerConvertible) -> [Pointee] {
        return metadata.advanced(by: offset.getInt()).vector(n: n.getInt()).map{ unsafeBitCast($0, to: Pointee.self) }
    }
}

extension RelativeVectorPointer: CustomStringConvertible {
    var description: String {
        return "\(offset)"
    }
}
