
import Foundation


protocol NominalMetadataLayoutType: MetadataLayoutType {
    var nominalTypeDescriptor: UnsafeMutablePointer<NominalTypeDescriptor> { get set }
}
