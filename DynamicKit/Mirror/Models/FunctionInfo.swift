
import Foundation


public struct FunctionInfo {
    public var numberOfArguments: Int
    public var argumentTypes: [Any.Type]
    public var returnType: Any.Type
    public var `throws`: Bool
}


public func functionInfo(of function: Any) throws -> FunctionInfo {
    return try functionInfo(of: type(of: function))
}

public func functionInfo(of type: Any.Type) throws -> FunctionInfo {
    let kind = Kind(type: type)
    guard kind == .function else { throw RuntimeError.couldNotGetTypeInfo(type: type, kind: kind) }
    return FunctionMetadata(type: type).info()
}
