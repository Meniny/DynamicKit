//
//  Locale+Boxing.swift
//  Boxing


import Foundation

extension Locale : Boxing {
    private enum CodingKeys : Int, BoxingKey {
        case identifier
    }

    public init(from unboxer: Unboxer) throws {
        let container = try unboxer.container(keyedBy: CodingKeys.self)
        let identifier = try container.unbox(String.self, forKey: .identifier)
        self.init(identifier: identifier)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.container(keyedBy: CodingKeys.self)
        try container.box(self.identifier, forKey: .identifier)
    }
}
