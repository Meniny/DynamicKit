//
//  Date+Boxing.swift
//  Boxing


import Foundation

extension Date : Boxing {
    public init(from unboxer: Unboxer) throws {
        // FIXME: This is a hook for bypassing a conditional conformance implementation to apply a strategy (see SR-5206). Remove this once conditional conformance is available.
        let container = try unboxer.singleValueContainer()
        if let unboxer = container as? _JSONUnboxer {
            switch unboxer.options.dateUnboxStrategy {
            case .deferredToDate:
                break /* fall back to default implementation below; this would recurse */

            default:
                // _JSONUnboxer has a hook for Dates; this won't recurse since we're not going to defer back to Date in _JSONUnboxer.
                self = try container.unbox(Date.self)
                return
            }
        }

        let timestamp = try container.unbox(Double.self)
        self = Date(timeIntervalSinceReferenceDate: timestamp)
    }

    public func box(to boxer: Boxer) throws {
        // FIXME: This is a hook for bypassing a conditional conformance implementation to apply a strategy (see SR-5206). Remove this once conditional conformance is available.
        // We are allowed to request this container as long as we don't box anything through it when we need the keyed container below.
        var container = boxer.singleValueContainer()
        if let boxer = container as? _JSONBoxer {
            switch boxer.options.dateBoxStrategy {
            case .deferredToDate:
                break /* fall back to default implementation below; this would recurse */

            default:
                // _JSONBoxer has a hook for Dates; this won't recurse since we're not going to defer back to Date in _JSONBoxer.
                try container.box(self)
                return
            }
        }

        try container.box(self.timeIntervalSinceReferenceDate)
    }
}
