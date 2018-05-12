//
//  Data+Boxing.swift
//  Boxing


import Foundation

extension Data : Boxing {
    public init(from unboxer: Unboxer) throws {
        // FIXME: This is a hook for bypassing a conditional conformance implementation to apply a strategy (see SR-5206). Remove this once conditional conformance is available.
        do {
            let singleValueContainer = try unboxer.singleValueContainer()
            if let unboxer = singleValueContainer as? _JSONUnboxer {
                switch unboxer.options.dataUnboxStrategy {
                case .deferredToData:
                    break /* fall back to default implementation below; this would recurse */

                default:
                    // _JSONUnboxer has a hook for Datas; this won't recurse since we're not going to defer back to Data in _JSONUnboxer.
                    self = try singleValueContainer.unbox(Data.self)
                    return
                }
            }
        } catch { /* fall back to default implementation below */ }

        var container = try unboxer.unkeyedContainer()

        // It's more efficient to pre-allocate the buffer if we can.
        if let count = container.count {
            self = Data(count: count)

            // Loop only until count, not while !container.isAtEnd, in case count is underestimated (this is misbehavior) and we haven't allocated enough space.
            // We don't want to write past the end of what we allocated.
            for i in 0 ..< count {
                let byte = try container.unbox(UInt8.self)
                self[i] = byte
            }
        } else {
            self = Data()
        }

        while !container.isAtEnd {
            var byte = try container.unbox(UInt8.self)
            self.append(&byte, count: 1)
        }
    }

    public func box(to boxer: Boxer) throws {
        // FIXME: This is a hook for bypassing a conditional conformance implementation to apply a strategy (see SR-5206). Remove this once conditional conformance is available.
        // We are allowed to request this container as long as we don't box anything through it when we need the unkeyed container below.
        var singleValueContainer = boxer.singleValueContainer()
        if let boxer = singleValueContainer as? _JSONBoxer {
            switch boxer.options.dataBoxStrategy {
            case .deferredToData:
                break /* fall back to default implementation below; this would recurse */

            default:
                // _JSONBoxer has a hook for Datas; this won't recurse since we're not going to defer back to Data in _JSONBoxer.
                try singleValueContainer.box(self)
                return
            }
        }

        var container = boxer.unkeyedContainer()

        // Since enumerateBytes does not rethrow, we need to catch the error, stow it away, and rethrow if we stopped.
        var caughtError: Error? = nil
        self.enumerateBytes { (buffer: UnsafeBufferPointer<UInt8>, byteIndex: Data.Index, stop: inout Bool) in
            do {
                try container.box(contentsOf: buffer)
            } catch {
                caughtError = error
                stop = true
            }
        }

        if let error = caughtError {
            throw error
        }
    }
}
