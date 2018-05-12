
import Foundation


struct StructMetadataLayout: NominalMetadataLayoutType {
    var valueWitnessTable: UnsafePointer<ValueWitnessTable>
    var kind: Int
    var nominalTypeDescriptor: UnsafeMutablePointer<NominalTypeDescriptor>
}
