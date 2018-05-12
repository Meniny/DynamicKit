//
//  IndexSet+Boxing.swift
//  Boxing


import Foundation

extension IndexSet : Boxing {
    private enum CodingKeys : Int, BoxingKey {
        case indexes
    }

    private enum RangeCodingKeys : Int, BoxingKey {
        case location
        case length
    }

    public init(from unboxer: Unboxer) throws {
        let container = try unboxer.container(keyedBy: CodingKeys.self)
        var indexesContainer = try container.nestedUnkeyedContainer(forKey: .indexes)
        self.init()

        while !indexesContainer.isAtEnd {
            let rangeContainer = try indexesContainer.nestedContainer(keyedBy: RangeCodingKeys.self)
            let startIndex = try rangeContainer.unbox(Int.self, forKey: .location)
            let count = try rangeContainer.unbox(Int.self, forKey: .length)
            self.insert(integersIn: startIndex ..< (startIndex + count))
        }
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.container(keyedBy: CodingKeys.self)
        var indexesContainer = container.nestedUnkeyedContainer(forKey: .indexes)

        for range in self.rangeView {
            var rangeContainer = indexesContainer.nestedContainer(keyedBy: RangeCodingKeys.self)
            try rangeContainer.box(range.startIndex, forKey: .location)
            try rangeContainer.box(range.count, forKey: .length)
        }
    }
}
