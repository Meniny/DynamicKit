
import Foundation


struct RelativePointer<Offset: IntegerConvertible, Pointee> {
    var offset: Offset
    
    mutating func pointee() -> Pointee {
        return advanced().pointee
    }
    
    mutating func advanced() -> UnsafeMutablePointer<Pointee> {
        let offsetCopy = self.offset
        return withUnsafePointer(to: &self) { p in
            return p.raw.advanced(by: offsetCopy.getInt()).assumingMemoryBound(to: Pointee.self).mutable
        }
    }
}

extension RelativePointer: CustomStringConvertible {
    var description: String {
        return "\(offset)"
    }
}
