
import Foundation


extension UnsafePointer {
    
    var raw: UnsafeRawPointer {
        return UnsafeRawPointer(self)
    }
    
    var mutable: UnsafeMutablePointer<Pointee> {
        return UnsafeMutablePointer<Pointee>(mutating: self)
    }
    
    func vector(n: IntegerConvertible) -> [Pointee] {
        var result = [Pointee]()
        for i in 0..<n.getInt() {
            result.append(advanced(by: i).pointee)
        }
        return result
    }
}

extension UnsafePointer where Pointee: Equatable {
    func advance(to value: Pointee) -> UnsafePointer<Pointee> {
        var pointer = self
        while pointer.pointee != value {
            pointer = pointer.advanced(by: 1)
        }
        return pointer
    }
}

extension UnsafeMutablePointer {
    
    var raw: UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(self)
    }
    
    func vector(n: IntegerConvertible) -> [Pointee] {
        var result = [Pointee]()
        for i in 0..<n.getInt() {
            result.append(advanced(by: i).pointee)
        }
        return result
    }
}
