
import Foundation


struct StructMetadata: NominalMetadataType {
    var type: Any.Type
    var metadata: UnsafeMutablePointer<StructMetadataLayout>
    var nominalTypeDescriptor: UnsafeMutablePointer<NominalTypeDescriptor>
    var base: UnsafeMutablePointer<Int>
}
