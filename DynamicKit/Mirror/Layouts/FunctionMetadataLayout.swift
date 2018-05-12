
import Foundation



struct FunctionMetadataLayout: MetadataLayoutType {
    var valueWitnessTable: UnsafePointer<ValueWitnessTable>
    var kind: Int
    var flags: Int
    var argumentVector: Vector<Any.Type>
}
