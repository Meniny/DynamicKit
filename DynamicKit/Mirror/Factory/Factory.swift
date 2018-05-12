
import Foundation

public func createInstance<T>(constructor: ((PropertyInfo) throws -> Any)? = nil) throws -> T {
    if let value = try createInstance(of: T.self, constructor: constructor) as? T {
        return value
    }
    
    throw RuntimeError.unableToBuildType(type: T.self)
}

public func createInstance(of type: Any.Type, constructor: ((PropertyInfo) throws -> Any)? = nil) throws -> Any {
    
    if let defaultConstructor = type as? DefaultConstructor.Type {
        return defaultConstructor.init()
    }
    
    let kind = Kind(type: type)
    
    #if os(iOS) // does not work on macOS or Linux
        switch kind {
        case .struct:
            return try buildStruct(type: type, constructor: constructor)
        case .class:
            return try buildClass(type: type)
        default:
            throw RuntimeError.unableToBuildType(type: type)
        }
    #else // class does not work on macOS or Linux
        switch kind {
        case .struct:
            return try buildStruct(type: type, constructor: constructor)
        default:
            throw RuntimeError.unableToBuildType(type: type)
        }
    #endif
}

func buildStruct(type: Any.Type, constructor: ((PropertyInfo) throws -> Any)? = nil) throws -> Any {
    let info = try typeInfo(of: type)
    let pointer = UnsafeMutableRawPointer.allocate(byteCount: info.size, alignment: info.alignment)
    defer { pointer.deallocate() }
    try setProperties(typeInfo: info, pointer: pointer, constructor: constructor)
    return getters(type: type).get(from: pointer)
}

#if os(iOS) // does not work on macOS or Linux
    func buildClass(type: Any.Type) throws -> Any {
        let info = try typeInfo(of: type)
        if let type = type as? AnyClass, var value = class_createInstance(type, 0) {
            try withClassValuePointer(of: &value) { pointer in
                try setProperties(typeInfo: info, pointer: pointer)
                let header = pointer.assumingMemoryBound(to: ClassHeader.self)
                header.pointee.strongRetainCounts = 2
            }
            return value
        }
        throw RuntimeError.unableToBuildType(type: type)
    }
#endif

func setProperties(typeInfo: TypeInfo, pointer: UnsafeMutableRawPointer, constructor: ((PropertyInfo) throws -> Any)? = nil) throws {
    for property in typeInfo.properties {
        let value = try constructor.map { (resolver) -> Any in
            return try resolver(property)
        } ?? defaultValue(of: property.type)
        
        let valuePointer = pointer.advanced(by: property.offset)
        let sets = setters(type: property.type)
        sets.set(value: value, pointer: valuePointer)
    }
}


func defaultValue(of type: Any.Type) throws -> Any {
    
    if let constructable = type as? DefaultConstructor.Type {
        return constructable.init()
    } else if let isOptional = type as? ExpressibleByNilLiteral.Type {
        return isOptional.init(nilLiteral: ())
    }
    
    return try createInstance(of: type)
}
