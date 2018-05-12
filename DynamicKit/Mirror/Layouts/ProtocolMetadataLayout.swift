
import Foundation



struct ProtocolMetadataLayout: MetadataLayoutType {
    var valueWitnessTable: UnsafePointer<ValueWitnessTable>
    var kind: Int
    var layoutFlags: Int
    var numberOfProtocols: Int
    var protocolDescriptorVector: UnsafeMutablePointer<ProtocolDescriptor>
}
