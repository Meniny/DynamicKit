//
//  CGFloat+Boxing.swift
//  Boxing


import Foundation

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import CoreGraphics
#endif

extension CGFloat : Boxing {
    @_transparent
    public init(from unboxer: Unboxer) throws {
        let container = try unboxer.singleValueContainer()
        do {
            self.native = try container.unbox(NativeType.self)
        } catch UnboxError.typeMismatch(let type, let context) {
            // We may have boxd as a different type on a different platform. A
            // strict fixed-format unboxer may disallow a conversion, so let's try the
            // other type.
            do {
                if NativeType.self == Float.self {
                    self.native = NativeType(try container.unbox(Double.self))
                } else {
                    self.native = NativeType(try container.unbox(Float.self))
                }
            } catch {
                // Failed to unbox as the other type, too. This is neither a Float nor
                // a Double. Throw the old error; we don't want to clobber the original
                // info.
                throw UnboxError.typeMismatch(type, context)
            }
        }
    }

    @_transparent
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.native)
    }
}
