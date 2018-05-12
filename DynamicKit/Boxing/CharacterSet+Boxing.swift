//
//  CharacterSet+Boxing.swift
//  Boxing


import Foundation

extension CharacterSet : Boxing {
    private enum CodingKeys : Int, BoxingKey {
        case bitmap
    }

    public init(from unboxer: Unboxer) throws {
        let container = try unboxer.container(keyedBy: CodingKeys.self)
        let bitmap = try container.unbox(Data.self, forKey: .bitmap)
        self.init(bitmapRepresentation: bitmap)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.container(keyedBy: CodingKeys.self)
        try container.box(self.bitmapRepresentation, forKey: .bitmap)
    }
}
