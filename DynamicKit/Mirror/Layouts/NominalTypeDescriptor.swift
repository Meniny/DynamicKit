
import Foundation


typealias FieldTypeAccessor = @convention(c) (UnsafePointer<Int>) -> UnsafePointer<Int>

struct NominalTypeDescriptor {
    var mangledName: RelativePointer<Int32, CChar>
    var numberOfFields: Int32
    var offsetToTheFieldOffsetVector: RelativeVectorPointer<Int32, Int>
    var fieldNames: RelativePointer<Int32, CChar>
    var fieldTypeAccessor: RelativePointer<Int32, Int>
    var metadataPattern: Int32
    var somethingNotInTheDocs: Int32
    var genericParameterVector: RelativeVectorPointer<Int32, Any.Type>
    var inclusiveGenericParametersCount: Int32
    var exclusiveGenericParametersCount: Int32
}
