
import Foundation



struct ExistentialContainer {
    let buffer: ExistentialContainerBuffer
    let type: Any.Type
    let witnessTable: Int
}

struct ExistentialContainerBuffer {
    let buffer1: Int
    let buffer2: Int
    let buffer3: Int
}


extension ExistentialContainerBuffer {
    static func size() -> Int {
        return MemoryLayout<ExistentialContainerBuffer>.size
    }
}
