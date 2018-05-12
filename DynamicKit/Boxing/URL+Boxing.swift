//
//  URL+Boxing.swift
//  Boxing


import Foundation

extension URL : Boxing {
    private enum CodingKeys : Int, BoxingKey {
        case base
        case relative
    }

    public init(from unboxer: Unboxer) throws {
        // FIXME: This is a hook for bypassing a conditional conformance implementation to apply a strategy (see SR-5206). Remove this once conditional conformance is available.
        do {
            // We are allowed to request this container as long as we don't unbox anything through it when we need the keyed container below.
            let singleValueContainer = try unboxer.singleValueContainer()
            if singleValueContainer is _JSONUnboxer {
                // _JSONUnboxer has a hook for URLs; this won't recurse since we're not going to defer back to URL in _JSONUnboxer.
                self = try singleValueContainer.unbox(URL.self)
                return
            }
        } catch { /* Fall back to default implementation below. */ }

        let container = try unboxer.container(keyedBy: CodingKeys.self)
        let relative = try container.unbox(String.self, forKey: .relative)
        let base = try container.unboxIfPresent(URL.self, forKey: .base)

        guard let url = URL(string: relative, relativeTo: base) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath,
                                                                    debugDescription: "Invalid URL string."))
        }

        self = url
    }

    public func box(to boxer: Boxer) throws {
        // FIXME: This is a hook for bypassing a conditional conformance implementation to apply a strategy (see SR-5206). Remove this once conditional conformance is available.
        // We are allowed to request this container as long as we don't box anything through it when we need the keyed container below.
        var singleValueContainer = boxer.singleValueContainer()
        if singleValueContainer is _JSONBoxer {
            // _JSONBoxer has a hook for URLs; this won't recurse since we're not going to defer back to URL in _JSONBoxer.
            try singleValueContainer.box(self)
            return
        }

        var container = boxer.container(keyedBy: CodingKeys.self)
        try container.box(self.relativeString, forKey: .relative)
        if let base = self.baseURL {
            try container.box(base, forKey: .base)
        }
    }
}
