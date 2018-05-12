
import Foundation



struct ClassMetadata: NominalMetadataType {
    
    var type: Any.Type
    var metadata: UnsafeMutablePointer<ClassMetadataLayout>
    var nominalTypeDescriptor: UnsafeMutablePointer<NominalTypeDescriptor>
    var base: UnsafeMutablePointer<Int>
    
    func superClassMetadata() -> ClassMetadata? {
        return metadata.pointee.superClass != swiftObject() ? ClassMetadata(type: metadata.pointee.superClass) : nil
    }
    
    mutating func toTypeInfo() -> TypeInfo {
        var info = TypeInfo(nominalMetadata: self)
        info.properties = properties()
        var superClass = superClassMetadata()
        while var sc = superClass {
            info.inheritance.append(sc.type)
            let superInfo = sc.toTypeInfo()
            info.properties.append(contentsOf: superInfo.properties)
            superClass = sc.superClassMetadata()
        }
        return info
    }
}
