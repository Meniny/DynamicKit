
import Foundation


extension Array where Element == String {
    
    static func from(pointer: UnsafePointer<CChar>, n: Int) -> [String] {
        var pointer = pointer
        var result = [String]()
        
        for _ in 0..<n {
            result.append(String(cString: pointer))
            pointer = pointer.advance(to: 0).advanced(by: 1)
        }
        
        return result
    }
}
