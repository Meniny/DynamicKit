
import Foundation

public struct TypeInfo {
    
    public var kind: Kind = .class
    public var name: String = ""
    public var type: Any.Type = Any.self
    public var mangledName: String = ""
    public var properties: [PropertyInfo] = []
    public var inheritance: [Any.Type] = []
    public var genericTypes: [Any.Type] = []
    public var size: Int = 0
    public var alignment: Int = 0
    public var stride: Int = 0
    
    init<Metadata: MetadataType>(metadata: Metadata) {
        kind = metadata.kind
        size = metadata.size
        alignment = metadata.alignment
        stride = metadata.stride
        type = metadata.type
        name = String(describing: metadata.type)
    }
    
    init<Metadata: NominalMetadataType>(nominalMetadata: Metadata) {
        self.init(metadata: nominalMetadata)
        var nominalMetadata = nominalMetadata
        mangledName = nominalMetadata.mangledName()
        genericTypes = nominalMetadata.genericParameters()
    }
    
    public var superClass: Any.Type? {
        return inheritance.first
    }
    
    public func property(named: String) throws -> PropertyInfo {
        if let prop = properties.first(where: { $0.name == named }) {
            return prop
        }
        
        throw RuntimeError.noPropertyNamed(name: named)
    }
}

public func typeInfo(of type: Any.Type) throws -> TypeInfo {
    let kind = Kind(type: type)
    
    var typeInfoConvertible: TypeInfoConvertible
    
    switch kind {
    case .struct:
        typeInfoConvertible = StructMetadata(type: type)
    case .class:
        typeInfoConvertible = ClassMetadata(type: type)
    case .existential:
        typeInfoConvertible = ProtocolMetadata(type: type)
    case .tuple:
        typeInfoConvertible = TupleMetadata(type: type)
    case .enum:
        typeInfoConvertible = EnumMetadata(type: type)
    default:
        throw RuntimeError.couldNotGetTypeInfo(type: type, kind: kind)
    }
    
    return typeInfoConvertible.toTypeInfo()
}
