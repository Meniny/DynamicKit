
import Foundation



func metadataPointer(type: Any.Type) -> UnsafeMutablePointer<Int> {
    return unsafeBitCast(type, to: UnsafeMutablePointer<Int>.self)
}

func metadata(of type: Any.Type) throws -> MetadataInfo {
    
    let kind = Kind(type: type)
    
    switch kind {
    case .struct:
        return StructMetadata(type: type)
    case .class:
        return ClassMetadata(type: type)
    case .existential:
        return ProtocolMetadata(type: type)
    case .tuple:
        return TupleMetadata(type: type)
    case .enum:
        return EnumMetadata(type: type)
    default:
        throw RuntimeError.couldNotGetTypeInfo(type: type, kind: kind)
    }
}

func swiftObject() -> Any.Type {
    class Temp {}
    let md = ClassMetadata(type: Temp.self)
    return md.metadata.pointee.superClass
}

