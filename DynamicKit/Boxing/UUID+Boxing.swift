//
//  UUID+Boxing.swift
//  Boxing


import Foundation

extension UUID : Boxing {
    public init(from unboxer: Unboxer) throws {
        let container = try unboxer.singleValueContainer()
        let uuidString = try container.unbox(String.self)

        guard let uuid = UUID(uuidString: uuidString) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath,
                                                                    debugDescription: "Attempted to unbox UUID from invalid UUID string."))
        }

        self = uuid
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.uuidString)
    }
}
