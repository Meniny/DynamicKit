//
//  NSRange+Boxing.swift
//  Boxing


import Foundation

extension NSRange : Boxing {
    public init(from unboxer: Unboxer) throws {
        var container = try unboxer.unkeyedContainer()
        let location = try container.unbox(Int.self)
        let length = try container.unbox(Int.self)
        self.init(location: location, length: length)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.unkeyedContainer()
        try container.box(self.location)
        try container.box(self.length)
    }
}
