
import Foundation

enum RuntimeError: Error {
    case couldNotGetTypeInfo(type: Any.Type, kind: Kind)
    case couldNotGetPointer(type: Any.Type, value: Any)
    case noPropertyNamed(name: String)
    case unableToBuildType(type: Any.Type)
    case errorGettingValue(name: String, type: Any.Type)
}
