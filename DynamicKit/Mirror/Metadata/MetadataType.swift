
import Foundation

protocol MetadataInfo {
    
    var kind: Kind { get }
    var size: Int { get }
    var alignment: Int { get }
    var stride: Int { get }
    
    init(type: Any.Type)
}

protocol MetadataType: MetadataInfo, TypeInfoConvertible {
    associatedtype Layout: MetadataLayoutType
    var type: Any.Type { get set }
    var metadata: UnsafeMutablePointer<Layout> { get set }
    var base: UnsafeMutablePointer<Int> { get set }
    init(type: Any.Type, metadata: UnsafeMutablePointer<Layout>, base: UnsafeMutablePointer<Int>)
}

extension MetadataType {
    
    var kind: Kind {
        return Kind(flag: base.pointee)
    }
    
    var size: Int {
        return metadata.pointee.valueWitnessTable.pointee.size
    }
    
    var alignment: Int {
        return (metadata.pointee.valueWitnessTable.pointee.flags & ValueWitnessFlags.alignmentMask) + 1
    }
    
    var stride: Int {
        return metadata.pointee.valueWitnessTable.pointee.stride
    }
    
    init(type: Any.Type) {
        let base = metadataPointer(type: type)
        let metadata = base.advanced(by: valueWitnessTableOffset).raw.assumingMemoryBound(to: Layout.self)
        self.init(type: type, metadata: metadata, base: base)
    }
    
    mutating func toTypeInfo() -> TypeInfo {
        return TypeInfo(metadata: self)
    }
}
