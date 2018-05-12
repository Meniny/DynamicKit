//
//  Decimal+Boxing.swift
//  Boxing


import Foundation

extension Decimal : Boxing {
    private enum CodingKeys : Int, BoxingKey {
        case exponent
        case length
        case isNegative
        case isCompact
        case mantissa
    }

    public init(from unboxer: Unboxer) throws {
        // FIXME: This is a hook for bypassing a conditional conformance implementation to apply a strategy (see SR-5206). Remove this once conditional conformance is available.
        do {
            // We are allowed to request this container as long as we don't unbox anything through it when we need the keyed container below.
            let singleValueContainer = try unboxer.singleValueContainer()
            if singleValueContainer is _JSONUnboxer {
                // _JSONUnboxer has a hook for Decimals; this won't recurse since we're not going to defer to Decimal in _JSONUnboxer.
                self  = try singleValueContainer.unbox(Decimal.self)
                return
            }
        } catch { /* Fall back to default implementation below. */ }

        let container = try unboxer.container(keyedBy: CodingKeys.self)
        let exponent = try container.unbox(CInt.self, forKey: .exponent)
        let length = try container.unbox(CUnsignedInt.self, forKey: .length)
        let isNegative = try container.unbox(Bool.self, forKey: .isNegative)
        let isCompact = try container.unbox(Bool.self, forKey: .isCompact)

        var mantissaContainer = try container.nestedUnkeyedContainer(forKey: .mantissa)
        var mantissa: (CUnsignedShort, CUnsignedShort, CUnsignedShort, CUnsignedShort,
            CUnsignedShort, CUnsignedShort, CUnsignedShort, CUnsignedShort) = (0,0,0,0,0,0,0,0)
        mantissa.0 = try mantissaContainer.unbox(CUnsignedShort.self)
        mantissa.1 = try mantissaContainer.unbox(CUnsignedShort.self)
        mantissa.2 = try mantissaContainer.unbox(CUnsignedShort.self)
        mantissa.3 = try mantissaContainer.unbox(CUnsignedShort.self)
        mantissa.4 = try mantissaContainer.unbox(CUnsignedShort.self)
        mantissa.5 = try mantissaContainer.unbox(CUnsignedShort.self)
        mantissa.6 = try mantissaContainer.unbox(CUnsignedShort.self)
        mantissa.7 = try mantissaContainer.unbox(CUnsignedShort.self)

        self = Decimal(_exponent: exponent,
                       _length: length,
                       _isNegative: CUnsignedInt(isNegative ? 1 : 0),
                       _isCompact: CUnsignedInt(isCompact ? 1 : 0),
                       _reserved: 0,
                       _mantissa: mantissa)
    }

    public func box(to boxer: Boxer) throws {
        // FIXME: This is a hook for bypassing a conditional conformance implementation to apply a strategy (see SR-5206). Remove this once conditional conformance is available.
        // We are allowed to request this container as long as we don't box anything through it when we need the keyed container below.
        var singleValueContainer = boxer.singleValueContainer()
        if singleValueContainer is _JSONBoxer {
            // _JSONBoxer has a hook for Decimals; this won't recurse since we're not going to defer to Decimal in _JSONBoxer.
            try singleValueContainer.box(self)
            return
        }

        var container = boxer.container(keyedBy: CodingKeys.self)
        try container.box(_exponent, forKey: .exponent)
        try container.box(_length, forKey: .length)
        try container.box(_isNegative == 0 ? false : true, forKey: .isNegative)
        try container.box(_isCompact == 0 ? false : true, forKey: .isCompact)

        var mantissaContainer = container.nestedUnkeyedContainer(forKey: .mantissa)
        try mantissaContainer.box(_mantissa.0)
        try mantissaContainer.box(_mantissa.1)
        try mantissaContainer.box(_mantissa.2)
        try mantissaContainer.box(_mantissa.3)
        try mantissaContainer.box(_mantissa.4)
        try mantissaContainer.box(_mantissa.5)
        try mantissaContainer.box(_mantissa.6)
        try mantissaContainer.box(_mantissa.7)
    }
}
