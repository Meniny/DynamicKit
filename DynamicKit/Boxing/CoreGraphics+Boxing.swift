//
//  CoreGraphics+Boxing.swift
//  Boxing

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

import CoreGraphics

extension CGPoint : Boxing {
    public init(from unboxer: Unboxer) throws {
        var container = try unboxer.unkeyedContainer()
        let x = try container.unbox(CGFloat.self)
        let y = try container.unbox(CGFloat.self)
        self.init(x: x, y: y)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.unkeyedContainer()
        try container.box(x)
        try container.box(y)
    }
}

extension CGSize : Boxing {
    public init(from unboxer: Unboxer) throws {
        var container = try unboxer.unkeyedContainer()
        let width = try container.unbox(CGFloat.self)
        let height = try container.unbox(CGFloat.self)
        self.init(width: width, height: height)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.unkeyedContainer()
        try container.box(width)
        try container.box(height)
    }
}

extension CGVector : Boxing {
    public init(from unboxer: Unboxer) throws {
        var container = try unboxer.unkeyedContainer()
        let dx = try container.unbox(CGFloat.self)
        let dy = try container.unbox(CGFloat.self)
        self.init(dx: dx, dy: dy)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.unkeyedContainer()
        try container.box(dx)
        try container.box(dy)
    }
}

extension CGRect : Boxing {
    public init(from unboxer: Unboxer) throws {
        var container = try unboxer.unkeyedContainer()
        let origin = try container.unbox(CGPoint.self)
        let size = try container.unbox(CGSize.self)
        self.init(origin: origin, size: size)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.unkeyedContainer()
        try container.box(origin)
        try container.box(size)
    }
}

extension CGAffineTransform : Boxing {
    public init(from unboxer: Unboxer) throws {
        var container = try unboxer.unkeyedContainer()
        let a = try container.unbox(CGFloat.self)
        let b = try container.unbox(CGFloat.self)
        let c = try container.unbox(CGFloat.self)
        let d = try container.unbox(CGFloat.self)
        let tx = try container.unbox(CGFloat.self)
        let ty = try container.unbox(CGFloat.self)
        self.init(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.unkeyedContainer()
        try container.box(a)
        try container.box(b)
        try container.box(c)
        try container.box(d)
        try container.box(tx)
        try container.box(ty)
    }
}
    
#endif

