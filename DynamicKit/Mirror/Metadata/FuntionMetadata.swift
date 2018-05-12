
import Foundation



struct FunctionMetadata: MetadataType {
    
    var type: Any.Type
    var metadata: UnsafeMutablePointer<FunctionMetadataLayout>
    var base: UnsafeMutablePointer<Int>
    
    func info() -> FunctionInfo {
        let (numberOfArguments, argumentTypes, returnType) = argumentInfo()
        return FunctionInfo(numberOfArguments: numberOfArguments,
                            argumentTypes: argumentTypes,
                            returnType: returnType,
                            throws: `throws`())
    }
    
    private func argumentInfo() -> (Int, [Any.Type], Any.Type) {
        let n = numberArguments()
        var argTypes = metadata.pointee.argumentVector.vector(n: n + 1)
        
        let resultType = argTypes[0]
        argTypes.removeFirst()
        
        return (n, argTypes, resultType)
    }
    
    private func numberArguments() -> Int {
        return metadata.pointee.flags & 0x00FFFFFF
    }
    
    private func `throws`() -> Bool {
        return metadata.pointee.flags & 0x01000000 != 0
    }
}
