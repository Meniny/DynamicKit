
import Foundation



struct EnumMetadataLayout: NominalMetadataLayoutType {
    var valueWitnessTable: UnsafePointer<ValueWitnessTable>
    var kind: Int
    var nominalTypeDescriptor: UnsafeMutablePointer<NominalTypeDescriptor>
    var parent: Int
}
