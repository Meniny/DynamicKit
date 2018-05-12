
import Foundation



struct EnumMetadata: NominalMetadataType {
    var type: Any.Type
    var metadata: UnsafeMutablePointer<EnumMetadataLayout>
    var nominalTypeDescriptor: UnsafeMutablePointer<NominalTypeDescriptor>
    var base: UnsafeMutablePointer<Int>
}
