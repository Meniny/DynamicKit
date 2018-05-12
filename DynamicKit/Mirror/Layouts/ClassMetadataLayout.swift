
import Foundation


struct ClassMetadataLayout: NominalMetadataLayoutType {
    var valueWitnessTable: UnsafePointer<ValueWitnessTable>
    var isaPointer: Int
    var superClass: Any.Type
    var objCRuntimeReserve1: Int
    var objCRuntimeReserve2: Int
    var rodataPointer: Int
    var classFlags: Int32
    var instanceAddressPoint: Int32
    var instanceSize: Int32
    var instanceAlignmentMask: Int16
    var runtimeReserveField: Int16
    var classObjectSize: Int32
    var classObjectAddressPoint: Int32
    var nominalTypeDescriptor: UnsafeMutablePointer<NominalTypeDescriptor>
}

