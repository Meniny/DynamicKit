//
//  IndexPath+Boxing.swift
//  Boxing


import Foundation

extension IndexPath : Boxing {
    private enum CodingKeys : Int, BoxingKey {
        case indexes
    }

    public init(from unboxer: Unboxer) throws {
        let container = try unboxer.container(keyedBy: CodingKeys.self)
        var indexesContainer = try container.nestedUnkeyedContainer(forKey: .indexes)

        var indexes = [Int]()
        if let count = indexesContainer.count {
            indexes.reserveCapacity(count)
        }

        while !indexesContainer.isAtEnd {
            let index = try indexesContainer.unbox(Int.self)
            indexes.append(index)
        }

        self.init(indexes: indexes)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.container(keyedBy: CodingKeys.self)
        var indexesContainer = container.nestedUnkeyedContainer(forKey: .indexes)

        for index in self {
            try indexesContainer.box(index)
        }
    }
}
