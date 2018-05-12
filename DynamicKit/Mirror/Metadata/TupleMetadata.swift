import Foundation



struct TupleMetadata: MetadataType, TypeInfoConvertible {
    
    var type: Any.Type
    var metadata: UnsafeMutablePointer<TupleMetadataLayout>
    var base: UnsafeMutablePointer<Int>
    
    func numberOfElements() -> Int {
        return metadata.pointee.numberOfElements
    }
    
    func labels() -> [String] {
        guard metadata.pointee.labelsString.hashValue != 0 else { return (0..<numberOfElements()).map{ a in "" } }
        var labels = String(cString: metadata.pointee.labelsString).components(separatedBy: " ")
        labels.removeLast()
        return labels
    }
    
    func elements() -> [TupleElementLayout] {
        let n = numberOfElements()
        guard n > 0 else { return [] }
        return metadata.pointee.elementVector.vector(n: n)
    }
    
    func properies() -> [PropertyInfo] {
        let names = labels()
        let el = elements()
        let num = numberOfElements()
        var properties = [PropertyInfo]()
        for i in 0..<num {
            properties.append(PropertyInfo(name: names[i], type: el[i].type, offset: el[i].offset, ownerType: type))
        }
        return properties
    }
    
    mutating func toTypeInfo() -> TypeInfo {
        var info = TypeInfo(metadata: self)
        info.properties = properies()
        return info
    }
}
