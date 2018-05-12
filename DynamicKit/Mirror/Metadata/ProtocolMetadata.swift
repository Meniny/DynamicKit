
import Foundation



struct ProtocolMetadata: MetadataType {
    
    var type: Any.Type
    var metadata: UnsafeMutablePointer<ProtocolMetadataLayout>
    var base: UnsafeMutablePointer<Int>
    var protocolDescriptor: UnsafeMutablePointer<ProtocolDescriptor>
    
    init(type: Any.Type, metadata: UnsafeMutablePointer<Layout>, base: UnsafeMutablePointer<Int>) {
        self.type = type
        self.metadata = metadata
        self.base = base
        self.protocolDescriptor = metadata.pointee.protocolDescriptorVector
    }
    
    mutating func mangledName() -> String {
        return String(cString: protocolDescriptor.pointee.mangledName)
    }
}
