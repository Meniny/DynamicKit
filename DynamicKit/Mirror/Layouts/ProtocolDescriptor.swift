
import Foundation



struct ProtocolDescriptor {
    var isaPointer: Int
    var mangledName: UnsafeMutablePointer<CChar>
    var inheritedProtocolsList: Int
    var requiredInstanceMethods: Int
    var requiredClassMethods: Int
    var optionalInstanceMethods: Int
    var optionalClassMethods: Int
    var instanceProperties: Int
    var protocolDescriptorSize: Int32
    var flags: Int32
}
