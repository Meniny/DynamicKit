
import Foundation

public struct PropertyInfo {
    
    public let name: String
    public let type: Any.Type
    public let offset: Int
    public let ownerType: Any.Type
    
    public func set<TObject>(value: Any, on object: inout TObject) throws {
        try withValuePointer(of: &object) { pointer in
            try set(value: value, pointer: pointer)
        }
    }
    
    public func set(value: Any, on object: inout Any) throws {
        try withValuePointer(of: &object) { pointer in
            try set(value: value, pointer: pointer)
        }
    }
    
    private func set(value: Any, pointer: UnsafeMutableRawPointer) throws {
        if Swift.type(of: value) != self.type { return }
        let valuePointer = pointer.advanced(by: offset)
        let sets = setters(type: type)
        sets.set(value: value, pointer: valuePointer)
    }
    
    public func get<TValue>(from object: Any) throws -> TValue {
        if let value = try get(from: object) as? TValue {
            return value
        }
        
        throw RuntimeError.errorGettingValue(name: name, type: type)
    }
    
    public func get(from object: Any) throws -> Any {
        var object = object
        return try withValuePointer(of: &object) { pointer in
            let valuePointer = pointer.advanced(by: offset)
            let gets = getters(type: type)
            return gets.get(from: valuePointer)
        }
    }
}


extension PropertyInfo: Equatable {
    public static func ==(lhs: PropertyInfo, rhs: PropertyInfo) -> Bool {
        return lhs.name == rhs.name
            && lhs.type == rhs.type
            && lhs.offset == rhs.offset
            && lhs.ownerType == rhs.ownerType
    }
}
