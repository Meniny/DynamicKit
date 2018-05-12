
import Foundation



struct TupleMetadataLayout: MetadataLayoutType {
    var valueWitnessTable: UnsafePointer<ValueWitnessTable>
    var kind: Int
    var numberOfElements: Int
    var labelsString: UnsafeMutablePointer<CChar>
    var elementVector: Vector<TupleElementLayout>
}


struct TupleElementLayout {
    var type: Any.Type
    var offset: Int
}
