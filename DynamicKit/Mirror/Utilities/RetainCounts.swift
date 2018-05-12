
import Foundation



public func retainCounts(of object: inout AnyObject) throws -> Int {
    return try withValuePointer(of: &object) { pointer in
        return pointer.assumingMemoryBound(to: ClassHeader.self).pointee.strongRetainCounts.getInt()
    }
}


public func weakRetainCounts(of object: inout AnyObject) throws -> Int {
    return try withValuePointer(of: &object) { pointer in
        return pointer.assumingMemoryBound(to: ClassHeader.self).pointee.weakRetainCounts.getInt()
    }
}
