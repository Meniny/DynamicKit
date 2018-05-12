//
//  AffineTransform+Boxing.swift
//  Boxing


import Foundation

#if os(macOS)
extension AffineTransform : Boxing {
    public init(from unboxer: Unboxer) throws {
        var container = try unboxer.unkeyedContainer()
        m11 = try container.unbox(CGFloat.self)
        m12 = try container.unbox(CGFloat.self)
        m21 = try container.unbox(CGFloat.self)
        m22 = try container.unbox(CGFloat.self)
        tX  = try container.unbox(CGFloat.self)
        tY  = try container.unbox(CGFloat.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.unkeyedContainer()
        try container.box(self.m11)
        try container.box(self.m12)
        try container.box(self.m21)
        try container.box(self.m22)
        try container.box(self.tX)
        try container.box(self.tY)
    }
}
#endif
