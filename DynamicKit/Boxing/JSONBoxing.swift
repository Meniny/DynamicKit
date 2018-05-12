//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation

//===----------------------------------------------------------------------===//
// JSON Boxer
//===----------------------------------------------------------------------===//

/// `JSONBoxer` facilitates the encoding of `Boxable` values into JSON.
open class JSONBoxer {
    // MARK: Options

    /// The formatting of the output JSON data.
    public struct OutputFormatting : OptionSet {
        /// The format's default value.
        public let rawValue: UInt

        /// Creates an OutputFormatting value with the given raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Produce human-readable JSON with indented output.
        public static let prettyPrinted = OutputFormatting(rawValue: 1 << 0)

        /// Produce JSON with dictionary keys sorted in lexicographic order.
        @available(OSX 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)
    }

    /// The strategy to use for encoding `Date` values.
    public enum DateBoxStrategy {
        /// Defer to `Date` for choosing an encoding. This is the default strategy.
        case deferredToDate

        /// Box the `Date` as a UNIX timestamp (as a JSON number).
        case secondsSince1970

        /// Box the `Date` as UNIX millisecond timestamp (as a JSON number).
        case millisecondsSince1970

        /// Box the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Box the `Date` as a string formatted by the given formatter.
        case formatted(DateFormatter)

        /// Box the `Date` as a custom value boxd by the given closure.
        ///
        /// If the closure fails to box a value into the given boxer, the boxer will box an empty automatic container in its place.
        case custom((Date, Boxer) throws -> Void)
    }

    /// The strategy to use for encoding `Data` values.
    public enum DataBoxStrategy {
        /// Defer to `Data` for choosing an encoding.
        case deferredToData

        /// Boxd the `Data` as a Base64-boxd string. This is the default strategy.
        case base64

        /// Box the `Data` as a custom value boxd by the given closure.
        ///
        /// If the closure fails to box a value into the given boxer, the boxer will box an empty automatic container in its place.
        case custom((Data, Boxer) throws -> Void)
    }

    /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatBoxStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case `throw`

        /// Box the values using the given representation strings.
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The output format to produce. Defaults to `[]`.
    open var outputFormatting: OutputFormatting = []

    /// The strategy to use in encoding dates. Defaults to `.deferredToDate`.
    open var dateBoxStrategy: DateBoxStrategy = .deferredToDate

    /// The strategy to use in encoding binary data. Defaults to `.base64`.
    open var dataBoxStrategy: DataBoxStrategy = .base64

    /// The strategy to use in encoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatBoxStrategy: NonConformingFloatBoxStrategy = .throw

    /// Contextual user-provided information for use during encoding.
    open var userInfo: [CodingUserInfoKey : Any] = [:]

    /// Options set on the top-level boxer to pass down the encoding hierarchy.
    internal struct _Options {
        let dateBoxStrategy: DateBoxStrategy
        let dataBoxStrategy: DataBoxStrategy
        let nonConformingFloatBoxStrategy: NonConformingFloatBoxStrategy
        let userInfo: [CodingUserInfoKey : Any]
    }

    /// The options set on the top-level boxer.
    fileprivate var options: _Options {
        return _Options(dateBoxStrategy: dateBoxStrategy,
                        dataBoxStrategy: dataBoxStrategy,
                        nonConformingFloatBoxStrategy: nonConformingFloatBoxStrategy,
                        userInfo: userInfo)
    }

    // MARK: - Constructing a JSON Boxer

    /// Initializes `self` with default strategies.
    public init() {}

    // MARK: - Box Values

    /// Boxs the given top-level value and returns its JSON representation.
    ///
    /// - parameter value: The value to box.
    /// - returns: A new `Data` value containing the boxd JSON data.
    /// - throws: `BoxError.invalidValue` if a non-comforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    open func box<T : Boxable>(_ value: T) throws -> Data {
        let boxer = _JSONBoxer(options: self.options)
        try value.box(to: boxer)

        guard boxer.storage.count > 0 else {
            throw BoxError.invalidValue(value, BoxError.Context(boxingPath: [], debugDescription: "Top-level \(T.self) did not box any values."))
        }

        let topLevel = boxer.storage.popContainer()
        if topLevel is NSNull {
            throw BoxError.invalidValue(value, BoxError.Context(boxingPath: [], debugDescription: "Top-level \(T.self) boxd as null JSON fragment."))
        } else if topLevel is NSNumber {
            throw BoxError.invalidValue(value, BoxError.Context(boxingPath: [], debugDescription: "Top-level \(T.self) boxd as number JSON fragment."))
        } else if topLevel is NSString {
            throw BoxError.invalidValue(value, BoxError.Context(boxingPath: [], debugDescription: "Top-level \(T.self) boxd as string JSON fragment."))
        }

        let writingOptions = JSONSerialization.WritingOptions(rawValue: self.outputFormatting.rawValue)
        do {
            return try JSONSerialization.data(withJSONObject: topLevel, options: writingOptions)
        } catch {
            throw BoxError.invalidValue(value, BoxError.Context(boxingPath: [], debugDescription: "Unable to box the given top-level value to JSON.", underlyingError: error))
        }
    }
}

// MARK: - _JSONBoxer

internal class _JSONBoxer : Boxer {
    // MARK: Properties

    /// The boxer's storage.
    fileprivate var storage: _JSONBoxStorage

    /// Options set on the top-level boxer.
    internal let options: JSONBoxer._Options

    /// The path to the current point in encoding.
    public var boxingPath: [BoxingKey]

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level boxer options.
    fileprivate init(options: JSONBoxer._Options, boxingPath: [BoxingKey] = []) {
        self.options = options
        self.storage = _JSONBoxStorage()
        self.boxingPath = boxingPath
    }

    /// Returns whether a new element can be boxd at this coding path.
    ///
    /// `true` if an element has not yet been boxd at this coding path; `false` otherwise.
    fileprivate var canBoxNewValue: Bool {
        // Every time a new value gets boxd, the key it's boxd for is pushed onto the coding path (even if it's a nil key from an unkeyed container).
        // At the same time, every time a container is requested, a new value gets pushed onto the storage stack.
        // If there are more values on the storage stack than on the coding path, it means the value is requesting more than one container, which violates the precondition.
        //
        // This means that anytime something that can request a new container goes onto the stack, we MUST push a key onto the coding path.
        // Things which will not request containers do not need to have the coding path extended for them (but it doesn't matter if it is, because they will not reach here).
        return self.storage.count == self.boxingPath.count
    }

    // MARK: - Boxer Methods
    public func container<Key>(keyedBy: Key.Type) -> KeyedBoxingContainer<Key> {
        // If an existing keyed container was already requested, return that one.
        let topContainer: NSMutableDictionary
        if self.canBoxNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushKeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableDictionary else {
                preconditionFailure("Attempt to push new keyed encoding container when already previously boxd at this path.")
            }

            topContainer = container
        }

        let container = _JSONKeyedBoxingContainer<Key>(referencing: self, boxingPath: self.boxingPath, wrapping: topContainer)
        return KeyedBoxingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedBoxingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topContainer: NSMutableArray
        if self.canBoxNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushUnkeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableArray else {
                preconditionFailure("Attempt to push new unkeyed encoding container when already previously boxd at this path.")
            }

            topContainer = container
        }

        return _JSONUnkeyedBoxingContainer(referencing: self, boxingPath: self.boxingPath, wrapping: topContainer)
    }

    public func singleValueContainer() -> SingleValueBoxingContainer {
        return self
    }
}

// MARK: - Box Storage and Containers

fileprivate struct _JSONBoxStorage {
    // MARK: Properties

    /// The container stack.
    /// Elements may be any one of the JSON types (NSNull, NSNumber, NSString, NSArray, NSDictionary).
    private(set) fileprivate var containers: [NSObject] = []

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    fileprivate init() {}

    // MARK: - Modifying the Stack

    fileprivate var count: Int {
        return self.containers.count
    }

    fileprivate mutating func pushKeyedContainer() -> NSMutableDictionary {
        let dictionary = NSMutableDictionary()
        self.containers.append(dictionary)
        return dictionary
    }

    fileprivate mutating func pushUnkeyedContainer() -> NSMutableArray {
        let array = NSMutableArray()
        self.containers.append(array)
        return array
    }

    fileprivate mutating func push(container: NSObject) {
        self.containers.append(container)
    }

    fileprivate mutating func popContainer() -> NSObject {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.popLast()!
    }
}

// MARK: - Box Containers

fileprivate struct _JSONKeyedBoxingContainer<K : BoxingKey> : KeyedBoxingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the boxer we're writing to.
    private let boxer: _JSONBoxer

    /// A reference to the container we're writing to.
    private let container: NSMutableDictionary

    /// The path of coding keys taken to get to this point in encoding.
    private(set) public var boxingPath: [BoxingKey]

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(referencing boxer: _JSONBoxer, boxingPath: [BoxingKey], wrapping container: NSMutableDictionary) {
        self.boxer = boxer
        self.boxingPath = boxingPath
        self.container = container
    }

    // MARK: - KeyedBoxingContainerProtocol Methods

    public mutating func boxNil(forKey key: Key)               throws { self.container[NSString(string: key.stringValue)] = NSNull() }
    public mutating func box(_ value: Bool, forKey key: Key)   throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: Int, forKey key: Key)    throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: Int8, forKey key: Key)   throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: Int16, forKey key: Key)  throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: Int32, forKey key: Key)  throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: Int64, forKey key: Key)  throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: UInt, forKey key: Key)   throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: UInt8, forKey key: Key)  throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: UInt16, forKey key: Key) throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: UInt32, forKey key: Key) throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: UInt64, forKey key: Key) throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }
    public mutating func box(_ value: String, forKey key: Key) throws { self.container[NSString(string: key.stringValue)] = self.boxer._box(value) }

    public mutating func box(_ value: Float, forKey key: Key)  throws {
        // Since the float may be invalid and throw, the coding path needs to contain this key.
        self.boxer.boxingPath.append(key)
        defer { self.boxer.boxingPath.removeLast() }
        self.container[NSString(string: key.stringValue)] = try self.boxer._box(value)
    }

    public mutating func box(_ value: Double, forKey key: Key) throws {
        // Since the double may be invalid and throw, the coding path needs to contain this key.
        self.boxer.boxingPath.append(key)
        defer { self.boxer.boxingPath.removeLast() }
        self.container[NSString(string: key.stringValue)] = try self.boxer._box(value)
    }

    public mutating func box<T : Boxable>(_ value: T, forKey key: Key) throws {
        self.boxer.boxingPath.append(key)
        defer { self.boxer.boxingPath.removeLast() }
        self.container[NSString(string: key.stringValue)] = try self.boxer._box(value)
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedBoxingContainer<NestedKey> {
        let dictionary = NSMutableDictionary()
        self.container[NSString(string: key.stringValue)] = dictionary

        self.boxingPath.append(key)
        defer { self.boxingPath.removeLast() }

        let container = _JSONKeyedBoxingContainer<NestedKey>(referencing: self.boxer, boxingPath: self.boxingPath, wrapping: dictionary)
        return KeyedBoxingContainer(container)
    }

    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedBoxingContainer {
        let array = NSMutableArray()
        self.container[NSString(string: key.stringValue)] = array

        self.boxingPath.append(key)
        defer { self.boxingPath.removeLast() }
        return _JSONUnkeyedBoxingContainer(referencing: self.boxer, boxingPath: self.boxingPath, wrapping: array)
    }

    public mutating func superBoxer() -> Boxer {
        return _JSONReferencingBoxer(referencing: self.boxer, at: _JSONKey.super, wrapping: self.container)
    }

    public mutating func superBoxer(forKey key: Key) -> Boxer {
        return _JSONReferencingBoxer(referencing: self.boxer, at: key, wrapping: self.container)
    }
}

fileprivate struct _JSONUnkeyedBoxingContainer : UnkeyedBoxingContainer {
    // MARK: Properties

    /// A reference to the boxer we're writing to.
    private let boxer: _JSONBoxer

    /// A reference to the container we're writing to.
    private let container: NSMutableArray

    /// The path of coding keys taken to get to this point in encoding.
    private(set) public var boxingPath: [BoxingKey]

    /// The number of elements boxd into the container.
    public var count: Int {
        return self.container.count
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(referencing boxer: _JSONBoxer, boxingPath: [BoxingKey], wrapping container: NSMutableArray) {
        self.boxer = boxer
        self.boxingPath = boxingPath
        self.container = container
    }

    // MARK: - UnkeyedBoxingContainer Methods

    public mutating func boxNil()             throws { self.container.add(NSNull()) }
    public mutating func box(_ value: Bool)   throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: Int)    throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: Int8)   throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: Int16)  throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: Int32)  throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: Int64)  throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: UInt)   throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: UInt8)  throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: UInt16) throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: UInt32) throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: UInt64) throws { self.container.add(self.boxer._box(value)) }
    public mutating func box(_ value: String) throws { self.container.add(self.boxer._box(value)) }

    public mutating func box(_ value: Float)  throws {
        // Since the float may be invalid and throw, the coding path needs to contain this key.
        self.boxer.boxingPath.append(_JSONKey(index: self.count))
        defer { self.boxer.boxingPath.removeLast() }
        self.container.add(try self.boxer._box(value))
    }

    public mutating func box(_ value: Double) throws {
        // Since the double may be invalid and throw, the coding path needs to contain this key.
        self.boxer.boxingPath.append(_JSONKey(index: self.count))
        defer { self.boxer.boxingPath.removeLast() }
        self.container.add(try self.boxer._box(value))
    }

    public mutating func box<T : Boxable>(_ value: T) throws {
        self.boxer.boxingPath.append(_JSONKey(index: self.count))
        defer { self.boxer.boxingPath.removeLast() }
        self.container.add(try self.boxer._box(value))
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedBoxingContainer<NestedKey> {
        self.boxingPath.append(_JSONKey(index: self.count))
        defer { self.boxingPath.removeLast() }

        let dictionary = NSMutableDictionary()
        self.container.add(dictionary)

        let container = _JSONKeyedBoxingContainer<NestedKey>(referencing: self.boxer, boxingPath: self.boxingPath, wrapping: dictionary)
        return KeyedBoxingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() -> UnkeyedBoxingContainer {
        self.boxingPath.append(_JSONKey(index: self.count))
        defer { self.boxingPath.removeLast() }

        let array = NSMutableArray()
        self.container.add(array)
        return _JSONUnkeyedBoxingContainer(referencing: self.boxer, boxingPath: self.boxingPath, wrapping: array)
    }

    public mutating func superBoxer() -> Boxer {
        return _JSONReferencingBoxer(referencing: self.boxer, at: self.container.count, wrapping: self.container)
    }
}

extension _JSONBoxer : SingleValueBoxingContainer {
    // MARK: - SingleValueBoxingContainer Methods

    fileprivate func assertCanBoxNewValue() {
        precondition(self.canBoxNewValue, "Attempt to box value through single value container when previously value already boxd.")
    }

    public func boxNil() throws {
        assertCanBoxNewValue()
        self.storage.push(container: NSNull())
    }

    public func box(_ value: Bool) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: Int) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: Int8) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: Int16) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: Int32) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: Int64) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: UInt) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: UInt8) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: UInt16) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: UInt32) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: UInt64) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: String) throws {
        assertCanBoxNewValue()
        self.storage.push(container: _box(value))
    }

    public func box(_ value: Float) throws {
        assertCanBoxNewValue()
        try self.storage.push(container: _box(value))
    }

    public func box(_ value: Double) throws {
        assertCanBoxNewValue()
        try self.storage.push(container: _box(value))
    }

    public func box<T : Boxable>(_ value: T) throws {
        assertCanBoxNewValue()
        try self.storage.push(container: _box(value))
    }
}

// MARK: - Concrete Value Representations

extension _JSONBoxer {
    /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
    fileprivate func _box(_ value: Bool)   -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: Int)    -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: Int8)   -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: Int16)  -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: Int32)  -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: Int64)  -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: UInt)   -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: UInt8)  -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: UInt16) -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: UInt32) -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: UInt64) -> NSObject { return NSNumber(value: value) }
    fileprivate func _box(_ value: String) -> NSObject { return NSString(string: value) }

    fileprivate func _box(_ float: Float) throws -> NSObject {
        guard !float.isInfinite && !float.isNaN else {
            guard case let .convertToString(positiveInfinity: posInfString,
                                            negativeInfinity: negInfString,
                                            nan: nanString) = self.options.nonConformingFloatBoxStrategy else {
                                                throw BoxError._invalidFloatingPointValue(float, at: boxingPath)
            }

            if float == Float.infinity {
                return NSString(string: posInfString)
            } else if float == -Float.infinity {
                return NSString(string: negInfString)
            } else {
                return NSString(string: nanString)
            }
        }

        return NSNumber(value: float)
    }

    fileprivate func _box(_ double: Double) throws -> NSObject {
        guard !double.isInfinite && !double.isNaN else {
            guard case let .convertToString(positiveInfinity: posInfString,
                                            negativeInfinity: negInfString,
                                            nan: nanString) = self.options.nonConformingFloatBoxStrategy else {
                                                throw BoxError._invalidFloatingPointValue(double, at: boxingPath)
            }

            if double == Double.infinity {
                return NSString(string: posInfString)
            } else if double == -Double.infinity {
                return NSString(string: negInfString)
            } else {
                return NSString(string: nanString)
            }
        }

        return NSNumber(value: double)
    }

    fileprivate func _box(_ date: Date) throws -> NSObject {
        switch self.options.dateBoxStrategy {
        case .deferredToDate:
            // Must be called with a surrounding with(pushedKey:) call.
            try date.box(to: self)
            return self.storage.popContainer()

        case .secondsSince1970:
            return NSNumber(value: date.timeIntervalSince1970)

        case .millisecondsSince1970:
            return NSNumber(value: 1000.0 * date.timeIntervalSince1970)

        case .iso8601:
            if #available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                #if swift(>=3.1.1)
                return NSString(string: _iso8601Formatter.string(from: date))
                #else
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
                #endif
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }

        case .formatted(let formatter):
            return NSString(string: formatter.string(from: date))

        case .custom(let closure):
            let depth = self.storage.count
            try closure(date, self)

            guard self.storage.count > depth else {
                // The closure didn't box anything. Return the default keyed container.
                return NSDictionary()
            }

            // We can pop because the closure boxd something.
            return self.storage.popContainer()
        }
    }

    fileprivate func _box(_ data: Data) throws -> NSObject {
        switch self.options.dataBoxStrategy {
        case .deferredToData:
            // Must be called with a surrounding with(pushedKey:) call.
            try data.box(to: self)
            return self.storage.popContainer()

        case .base64:
            return NSString(string: data.base64EncodedString())

        case .custom(let closure):
            let depth = self.storage.count
            try closure(data, self)

            guard self.storage.count > depth else {
                // The closure didn't box anything. Return the default keyed container.
                return NSDictionary()
            }

            // We can pop because the closure boxd something.
            return self.storage.popContainer()
        }
    }

    fileprivate func _box<T : Boxable>(_ value: T) throws -> NSObject {
        if T.self == Date.self {
            // Respect Date encoding strategy
            return try self._box((value as! Date))
        } else if T.self == Data.self {
            // Respect Data encoding strategy
            return try self._box((value as! Data))
        } else if T.self == URL.self {
            // Box URLs as single strings.
            return self._box((value as! URL).absoluteString)
        } else if T.self == Decimal.self {
            // JSONSerialization can natively handle NSDecimalNumber.
            #if swift(>=3.1.1) || os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            return (value as! Decimal) as NSDecimalNumber
            #else
            fatalError("\(NSDecimalNumber.self) not supported")
            #endif
        }

        // The value should request a container from the _JSONBoxer.
        let topContainer = self.storage.containers.last
        try value.box(to: self)

        // The top container should be a new container.
        guard self.storage.containers.last! !== topContainer else {
            // If the value didn't request a container at all, box the default container instead.
            return NSDictionary()
        }

        return self.storage.popContainer()
    }
}

// MARK: - _JSONReferencingBoxer

/// _JSONReferencingBoxer is a special subclass of _JSONBoxer which has its own storage, but references the contents of a different boxer.
/// It's used in superBoxer(), which returns a new boxer for encoding a superclass -- the lifetime of the boxer should not escape the scope it's created in, but it doesn't necessarily know when it's done being used (to write to the original container).
fileprivate class _JSONReferencingBoxer : _JSONBoxer {
    // MARK: Reference types.

    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(NSMutableArray, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(NSMutableDictionary, String)
    }

    // MARK: - Properties

    /// The boxer we're referencing.
    fileprivate let boxer: _JSONBoxer

    /// The container reference itself.
    private let reference: Reference

    // MARK: - Initialization

    /// Initializes `self` by referencing the given array container in the given boxer.
    fileprivate init(referencing boxer: _JSONBoxer, at index: Int, wrapping array: NSMutableArray) {
        self.boxer = boxer
        self.reference = .array(array, index)
        super.init(options: boxer.options, boxingPath: boxer.boxingPath)

        self.boxingPath.append(_JSONKey(index: index))
    }

    /// Initializes `self` by referencing the given dictionary container in the given boxer.
    fileprivate init(referencing boxer: _JSONBoxer, at key: BoxingKey, wrapping dictionary: NSMutableDictionary) {
        self.boxer = boxer
        self.reference = .dictionary(dictionary, key.stringValue)
        super.init(options: boxer.options, boxingPath: boxer.boxingPath)

        self.boxingPath.append(key)
    }

    // MARK: - Coding Path Operations

    fileprivate override var canBoxNewValue: Bool {
        // With a regular boxer, the storage and coding path grow together.
        // A referencing boxer, however, inherits its parents coding path, as well as the key it was created for.
        // We have to take this into account.
        return self.storage.count == self.boxingPath.count - self.boxer.boxingPath.count - 1
    }

    // MARK: - Deinitialization

    // Finalizes `self` by writing the contents of our storage to the referenced boxer's storage.
    deinit {
        let value: Any
        switch self.storage.count {
        case 0: value = NSDictionary()
        case 1: value = self.storage.popContainer()
        default: fatalError("Referencing boxer deallocated with multiple containers on stack.")
        }

        switch self.reference {
        case .array(let array, let index):
            array.insert(value, at: index)

        case .dictionary(let dictionary, let key):
            dictionary[NSString(string: key)] = value
        }
    }
}

//===----------------------------------------------------------------------===//
// JSON Unboxer
//===----------------------------------------------------------------------===//

/// `JSONUnboxer` facilitates the decoding of JSON into semantic `Unboxable` types.
open class JSONUnboxer {
    // MARK: Options

    /// The strategy to use for decoding `Date` values.
    public enum DateUnboxStrategy {
        /// Defer to `Date` for decoding. This is the default strategy.
        case deferredToDate

        /// Unbox the `Date` as a UNIX timestamp from a JSON number.
        case secondsSince1970

        /// Unbox the `Date` as UNIX millisecond timestamp from a JSON number.
        case millisecondsSince1970

        /// Unbox the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Unbox the `Date` as a string parsed by the given formatter.
        case formatted(DateFormatter)

        /// Unbox the `Date` as a custom value unboxd by the given closure.
        case custom((_ unboxer: Unboxer) throws -> Date)
    }

    /// The strategy to use for decoding `Data` values.
    public enum DataUnboxStrategy {
        /// Defer to `Data` for decoding.
        case deferredToData

        /// Unbox the `Data` from a Base64-boxd string. This is the default strategy.
        case base64

        /// Unbox the `Data` as a custom value unboxd by the given closure.
        case custom((_ unboxer: Unboxer) throws -> Data)
    }

    /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatUnboxStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case `throw`

        /// Unbox the values from the given representation strings.
        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use in decoding dates. Defaults to `.deferredToDate`.
    open var dateUnboxStrategy: DateUnboxStrategy = .deferredToDate

    /// The strategy to use in decoding binary data. Defaults to `.base64`.
    open var dataUnboxStrategy: DataUnboxStrategy = .base64

    /// The strategy to use in decoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatUnboxStrategy: NonConformingFloatUnboxStrategy = .throw

    /// Contextual user-provided information for use during decoding.
    open var userInfo: [CodingUserInfoKey : Any] = [:]

    /// Options set on the top-level boxer to pass down the decoding hierarchy.
    internal struct _Options {
        let dateUnboxStrategy: DateUnboxStrategy
        let dataUnboxStrategy: DataUnboxStrategy
        let nonConformingFloatUnboxStrategy: NonConformingFloatUnboxStrategy
        let userInfo: [CodingUserInfoKey : Any]
    }

    /// The options set on the top-level unboxer.
    fileprivate var options: _Options {
        return _Options(dateUnboxStrategy: dateUnboxStrategy,
                        dataUnboxStrategy: dataUnboxStrategy,
                        nonConformingFloatUnboxStrategy: nonConformingFloatUnboxStrategy,
                        userInfo: userInfo)
    }

    // MARK: - Constructing a JSON Unboxer

    /// Initializes `self` with default strategies.
    public init() {}

    // MARK: - Unbox Values

    /// Unboxs a top-level value of the given type from the given JSON representation.
    ///
    /// - parameter type: The type of the value to unbox.
    /// - parameter data: The data to unbox from.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not valid JSON.
    /// - throws: An error if any value throws an error during decoding.
    open func unbox<T : Unboxable>(_ type: T.Type, from data: Data) throws -> T {
        let topLevel: Any
        do {
            topLevel = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: [], debugDescription: "The given data was not valid JSON.", underlyingError: error))
        }

        let unboxer = _JSONUnboxer(referencing: topLevel, options: self.options)
        return try T(from: unboxer)
    }
}

// MARK: - _JSONUnboxer

internal class _JSONUnboxer : Unboxer {
    // MARK: Properties

    /// The unboxer's storage.
    fileprivate var storage: _JSONUnboxStorage

    /// Options set on the top-level unboxer.
    internal let options: JSONUnboxer._Options

    /// The path to the current point in encoding.
    fileprivate(set) public var boxingPath: [BoxingKey]

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level container and options.
    fileprivate init(referencing container: Any, at boxingPath: [BoxingKey] = [], options: JSONUnboxer._Options) {
        self.storage = _JSONUnboxStorage()
        self.storage.push(container: container)
        self.boxingPath = boxingPath
        self.options = options
    }

    // MARK: - Unboxer Methods

    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedUnboxingContainer<Key> {
        guard !(self.storage.topContainer is NSNull) else {
            throw UnboxError.valueNotFound(KeyedUnboxingContainer<Key>.self,
                                              UnboxError.Context(boxingPath: self.boxingPath,
                                                                    debugDescription: "Cannot get keyed decoding container -- found null value instead."))
        }

        guard let topContainer = self.storage.topContainer as? [String : Any] else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: [String : Any].self, reality: self.storage.topContainer)
        }

        let container = _JSONKeyedUnboxingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedUnboxingContainer(container)
    }

    public func unkeyedContainer() throws -> UnkeyedUnboxingContainer {
        guard !(self.storage.topContainer is NSNull) else {
            throw UnboxError.valueNotFound(UnkeyedUnboxingContainer.self,
                                              UnboxError.Context(boxingPath: self.boxingPath,
                                                                    debugDescription: "Cannot get unkeyed decoding container -- found null value instead."))
        }

        guard let topContainer = self.storage.topContainer as? [Any] else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: [Any].self, reality: self.storage.topContainer)
        }

        return _JSONUnkeyedUnboxingContainer(referencing: self, wrapping: topContainer)
    }

    public func singleValueContainer() throws -> SingleValueUnboxingContainer {
        return self
    }
}

// MARK: - Unbox Storage

fileprivate struct _JSONUnboxStorage {
    // MARK: Properties

    /// The container stack.
    /// Elements may be any one of the JSON types (NSNull, NSNumber, String, Array, [String : Any]).
    private(set) fileprivate var containers: [Any] = []

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    fileprivate init() {}

    // MARK: - Modifying the Stack

    fileprivate var count: Int {
        return self.containers.count
    }

    fileprivate var topContainer: Any {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.last!
    }

    fileprivate mutating func push(container: Any) {
        self.containers.append(container)
    }

    fileprivate mutating func popContainer() {
        precondition(self.containers.count > 0, "Empty container stack.")
        self.containers.removeLast()
    }
}

// MARK: Unbox Containers

fileprivate struct _JSONKeyedUnboxingContainer<K : BoxingKey> : KeyedUnboxingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the unboxer we're reading from.
    private let unboxer: _JSONUnboxer

    /// A reference to the container we're reading from.
    private let container: [String : Any]

    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var boxingPath: [BoxingKey]

    // MARK: - Initialization

    /// Initializes `self` by referencing the given unboxer and container.
    fileprivate init(referencing unboxer: _JSONUnboxer, wrapping container: [String : Any]) {
        self.unboxer = unboxer
        self.container = container
        self.boxingPath = unboxer.boxingPath
    }

    // MARK: - KeyedUnboxingContainerProtocol Methods

    public var allKeys: [Key] {
        return self.container.keys.compactMap { Key(stringValue: $0) }
    }

    public func contains(_ key: Key) -> Bool {
        return self.container[key.stringValue] != nil
    }

    public func unboxNil(forKey key: Key) throws -> Bool {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        return entry is NSNull
    }

    public func unbox(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: Bool.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: Int.Type, forKey key: Key) throws -> Int {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: Int.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: Int8.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: Int16.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: Int32.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: Int64.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: UInt.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: UInt8.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: UInt16.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: UInt32.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: UInt64.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: Float.Type, forKey key: Key) throws -> Float {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: Float.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: Double.Type, forKey key: Key) throws -> Double {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: Double.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox(_ type: String.Type, forKey key: Key) throws -> String {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: String.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func unbox<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard let entry = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }

        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = try self.unboxer.unbox(entry, as: T.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedUnboxingContainer<NestedKey> {
        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key,
                                            UnboxError.Context(boxingPath: self.boxingPath,
                                                                  debugDescription: "Cannot get \(KeyedUnboxingContainer<NestedKey>.self) -- no value found for key \"\(key.stringValue)\""))
        }

        guard let dictionary = value as? [String : Any] else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: [String : Any].self, reality: value)
        }

        let container = _JSONKeyedUnboxingContainer<NestedKey>(referencing: self.unboxer, wrapping: dictionary)
        return KeyedUnboxingContainer(container)
    }

    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedUnboxingContainer {
        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        guard let value = self.container[key.stringValue] else {
            throw UnboxError.keyNotFound(key,
                                            UnboxError.Context(boxingPath: self.boxingPath,
                                                                  debugDescription: "Cannot get UnkeyedUnboxingContainer -- no value found for key \"\(key.stringValue)\""))
        }

        guard let array = value as? [Any] else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: [Any].self, reality: value)
        }

        return _JSONUnkeyedUnboxingContainer(referencing: self.unboxer, wrapping: array)
    }

    private func _superUnboxer(forKey key: BoxingKey) throws -> Unboxer {
        self.unboxer.boxingPath.append(key)
        defer { self.unboxer.boxingPath.removeLast() }

        let value: Any = self.container[key.stringValue] ?? NSNull()
        return _JSONUnboxer(referencing: value, at: self.unboxer.boxingPath, options: self.unboxer.options)
    }

    public func superUnboxer() throws -> Unboxer {
        return try _superUnboxer(forKey: _JSONKey.super)
    }

    public func superUnboxer(forKey key: Key) throws -> Unboxer {
        return try _superUnboxer(forKey: key)
    }
}

fileprivate struct _JSONUnkeyedUnboxingContainer : UnkeyedUnboxingContainer {
    // MARK: Properties

    /// A reference to the unboxer we're reading from.
    private let unboxer: _JSONUnboxer

    /// A reference to the container we're reading from.
    private let container: [Any]

    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var boxingPath: [BoxingKey]

    /// The index of the element we're about to unbox.
    private(set) public var currentIndex: Int

    // MARK: - Initialization

    /// Initializes `self` by referencing the given unboxer and container.
    fileprivate init(referencing unboxer: _JSONUnboxer, wrapping container: [Any]) {
        self.unboxer = unboxer
        self.container = container
        self.boxingPath = unboxer.boxingPath
        self.currentIndex = 0
    }

    // MARK: - UnkeyedUnboxingContainer Methods

    public var count: Int? {
        return self.container.count
    }

    public var isAtEnd: Bool {
        return self.currentIndex >= self.count!
    }

    public mutating func unboxNil() throws -> Bool {
        guard !self.isAtEnd else {
            
            #if swift(>=3.1)
            throw UnboxError.valueNotFound(Any?.self, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
            #elseif swift(>=3.0)
            throw UnboxError.valueNotFound(Optional<Any>.self, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
            #endif
        }

        if self.container[self.currentIndex] is NSNull {
            self.currentIndex += 1
            return true
        } else {
            return false
        }
    }

    public mutating func unbox(_ type: Bool.Type) throws -> Bool {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: Bool.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: Int.Type) throws -> Int {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: Int.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: Int8.Type) throws -> Int8 {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: Int8.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: Int16.Type) throws -> Int16 {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: Int16.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: Int32.Type) throws -> Int32 {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: Int32.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: Int64.Type) throws -> Int64 {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: Int64.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: UInt.Type) throws -> UInt {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: UInt.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: UInt8.Type) throws -> UInt8 {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: UInt8.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: UInt16.Type) throws -> UInt16 {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: UInt16.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: UInt32.Type) throws -> UInt32 {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: UInt32.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: UInt64.Type) throws -> UInt64 {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: UInt64.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: Float.Type) throws -> Float {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: Float.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: Double.Type) throws -> Double {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: Double.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox(_ type: String.Type) throws -> String {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: String.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func unbox<T : Unboxable>(_ type: T.Type) throws -> T {
        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }

        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard let unboxd = try self.unboxer.unbox(self.container[self.currentIndex], as: T.self) else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.unboxer.boxingPath + [_JSONKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }

        self.currentIndex += 1
        return unboxd
    }

    public mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedUnboxingContainer<NestedKey> {
        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(KeyedUnboxingContainer<NestedKey>.self,
                                              UnboxError.Context(boxingPath: self.boxingPath,
                                                                    debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."))
        }

        let value = self.container[self.currentIndex]
        guard !(value is NSNull) else {
            throw UnboxError.valueNotFound(KeyedUnboxingContainer<NestedKey>.self,
                                              UnboxError.Context(boxingPath: self.boxingPath,
                                                                    debugDescription: "Cannot get keyed decoding container -- found null value instead."))
        }

        guard let dictionary = value as? [String : Any] else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: [String : Any].self, reality: value)
        }

        self.currentIndex += 1
        let container = _JSONKeyedUnboxingContainer<NestedKey>(referencing: self.unboxer, wrapping: dictionary)
        return KeyedUnboxingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() throws -> UnkeyedUnboxingContainer {
        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(UnkeyedUnboxingContainer.self,
                                              UnboxError.Context(boxingPath: self.boxingPath,
                                                                    debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."))
        }

        let value = self.container[self.currentIndex]
        guard !(value is NSNull) else {
            throw UnboxError.valueNotFound(UnkeyedUnboxingContainer.self,
                                              UnboxError.Context(boxingPath: self.boxingPath,
                                                                    debugDescription: "Cannot get keyed decoding container -- found null value instead."))
        }

        guard let array = value as? [Any] else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: [Any].self, reality: value)
        }

        self.currentIndex += 1
        return _JSONUnkeyedUnboxingContainer(referencing: self.unboxer, wrapping: array)
    }

    public mutating func superUnboxer() throws -> Unboxer {
        self.unboxer.boxingPath.append(_JSONKey(index: self.currentIndex))
        defer { self.unboxer.boxingPath.removeLast() }

        guard !self.isAtEnd else {
            throw UnboxError.valueNotFound(Unboxer.self,
                                              UnboxError.Context(boxingPath: self.boxingPath,
                                                                    debugDescription: "Cannot get superUnboxer() -- unkeyed container is at end."))
        }

        let value = self.container[self.currentIndex]
        self.currentIndex += 1
        return _JSONUnboxer(referencing: value, at: self.unboxer.boxingPath, options: self.unboxer.options)
    }
}

extension _JSONUnboxer : SingleValueUnboxingContainer {
    // MARK: SingleValueUnboxingContainer Methods

    private func expectNonNull<T>(_ type: T.Type) throws {
        guard !self.unboxNil() else {
            throw UnboxError.valueNotFound(type, UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Expected \(type) but found null value instead."))
        }
    }

    public func unboxNil() -> Bool {
        return self.storage.topContainer is NSNull
    }

    public func unbox(_ type: Bool.Type) throws -> Bool {
        try expectNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Bool.self)!
    }

    public func unbox(_ type: Int.Type) throws -> Int {
        try expectNonNull(Int.self)
        return try self.unbox(self.storage.topContainer, as: Int.self)!
    }

    public func unbox(_ type: Int8.Type) throws -> Int8 {
        try expectNonNull(Int8.self)
        return try self.unbox(self.storage.topContainer, as: Int8.self)!
    }

    public func unbox(_ type: Int16.Type) throws -> Int16 {
        try expectNonNull(Int16.self)
        return try self.unbox(self.storage.topContainer, as: Int16.self)!
    }

    public func unbox(_ type: Int32.Type) throws -> Int32 {
        try expectNonNull(Int32.self)
        return try self.unbox(self.storage.topContainer, as: Int32.self)!
    }

    public func unbox(_ type: Int64.Type) throws -> Int64 {
        try expectNonNull(Int64.self)
        return try self.unbox(self.storage.topContainer, as: Int64.self)!
    }

    public func unbox(_ type: UInt.Type) throws -> UInt {
        try expectNonNull(UInt.self)
        return try self.unbox(self.storage.topContainer, as: UInt.self)!
    }

    public func unbox(_ type: UInt8.Type) throws -> UInt8 {
        try expectNonNull(UInt8.self)
        return try self.unbox(self.storage.topContainer, as: UInt8.self)!
    }

    public func unbox(_ type: UInt16.Type) throws -> UInt16 {
        try expectNonNull(UInt16.self)
        return try self.unbox(self.storage.topContainer, as: UInt16.self)!
    }

    public func unbox(_ type: UInt32.Type) throws -> UInt32 {
        try expectNonNull(UInt32.self)
        return try self.unbox(self.storage.topContainer, as: UInt32.self)!
    }

    public func unbox(_ type: UInt64.Type) throws -> UInt64 {
        try expectNonNull(UInt64.self)
        return try self.unbox(self.storage.topContainer, as: UInt64.self)!
    }

    public func unbox(_ type: Float.Type) throws -> Float {
        try expectNonNull(Float.self)
        return try self.unbox(self.storage.topContainer, as: Float.self)!
    }

    public func unbox(_ type: Double.Type) throws -> Double {
        try expectNonNull(Double.self)
        return try self.unbox(self.storage.topContainer, as: Double.self)!
    }

    public func unbox(_ type: String.Type) throws -> String {
        try expectNonNull(String.self)
        return try self.unbox(self.storage.topContainer, as: String.self)!
    }

    public func unbox<T : Unboxable>(_ type: T.Type) throws -> T {
        try expectNonNull(T.self)
        return try self.unbox(self.storage.topContainer, as: T.self)!
    }
}

// MARK: - Concrete Value Representations

extension _JSONUnboxer {
    /// Returns the given value unboxed from a container.
    fileprivate func unbox(_ value: Any, as type: Bool.Type) throws -> Bool? {
        guard !(value is NSNull) else { return nil }

        if let number = value as? Bool {
            
            return number
            
        } else if let number = value as? NSNumber {
            #if swift(>=3.1.1) || os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            // TODO: Add a flag to coerce non-boolean numbers into Bools?
            if number === kCFBooleanTrue as NSNumber {
                return true
            } else if number === kCFBooleanFalse as NSNumber {
                return false
            }
            #else
            return number.boolValue
            #endif

            /* FIXME: If swift-corelibs-foundation doesn't change to use NSNumber, this code path will need to be included and tested:
             } else if let bool = value as? Bool {
             return bool
             */

        }

        throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
    }

    fileprivate func unbox(_ value: Any, as type: Int.Type) throws -> Int? {
        guard !(value is NSNull) else { return nil }

        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let int = number.intValue
        guard NSNumber(value: int) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        #else
        guard let int = value as? Int else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }
        #endif

        return int
    }

    fileprivate func unbox(_ value: Any, as type: Int8.Type) throws -> Int8? {
        guard !(value is NSNull) else { return nil }

        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let int8 = number.int8Value
        guard NSNumber(value: int8) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        #else
        guard let int8 = value as? Int8 else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }
        #endif

        return int8
    }

    fileprivate func unbox(_ value: Any, as type: Int16.Type) throws -> Int16? {
        guard !(value is NSNull) else { return nil }

        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let int16 = number.int16Value
        guard NSNumber(value: int16) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }

        return int16
    }

    fileprivate func unbox(_ value: Any, as type: Int32.Type) throws -> Int32? {
        guard !(value is NSNull) else { return nil }

        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let int32 = number.int32Value
        guard NSNumber(value: int32) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }

        return int32
    }

    fileprivate func unbox(_ value: Any, as type: Int64.Type) throws -> Int64? {
        guard !(value is NSNull) else { return nil }

        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let int64 = number.int64Value
        guard NSNumber(value: int64) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }

        return int64
    }

    fileprivate func unbox(_ value: Any, as type: UInt.Type) throws -> UInt? {
        guard !(value is NSNull) else { return nil }

        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let uint = number.uintValue
        guard NSNumber(value: uint) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }

        return uint
    }

    fileprivate func unbox(_ value: Any, as type: UInt8.Type) throws -> UInt8? {
        guard !(value is NSNull) else { return nil }

        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let uint8 = number.uint8Value
        guard NSNumber(value: uint8) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }

        return uint8
    }

    fileprivate func unbox(_ value: Any, as type: UInt16.Type) throws -> UInt16? {
        guard !(value is NSNull) else { return nil }

        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let uint16 = number.uint16Value
        guard NSNumber(value: uint16) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }

        return uint16
    }

    fileprivate func unbox(_ value: Any, as type: UInt32.Type) throws -> UInt32? {
        guard !(value is NSNull) else { return nil }

        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let uint32 = number.uint32Value
        guard NSNumber(value: uint32) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }

        return uint32
    }

    fileprivate func unbox(_ value: Any, as type: UInt64.Type) throws -> UInt64? {
        guard !(value is NSNull) else { return nil }

        guard let number = value as? NSNumber else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        let uint64 = number.uint64Value
        guard NSNumber(value: uint64) == number else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }

        return uint64
    }

    fileprivate func unbox(_ value: Any, as type: Float.Type) throws -> Float? {
        guard !(value is NSNull) else { return nil }

        if let number = value as? NSNumber {
            // We are willing to return a Float by losing precision:
            // * If the original value was integral,
            //   * and the integral value was > Float.greatestFiniteMagnitude, we will fail
            //   * and the integral value was <= Float.greatestFiniteMagnitude, we are willing to lose precision past 2^24
            // * If it was a Float, you will get back the precise value
            // * If it was a Double or Decimal, you will get back the nearest approximation if it will fit
            let double = number.doubleValue
            guard abs(double) <= Double(Float.greatestFiniteMagnitude) else {
                throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Parsed JSON number \(number) does not fit in \(type)."))
            }

            return Float(double)

            /* FIXME: If swift-corelibs-foundation doesn't change to use NSNumber, this code path will need to be included and tested:
             } else if let double = value as? Double {
             if abs(double) <= Double(Float.max) {
             return Float(double)
             }

             overflow = true
             } else if let int = value as? Int {
             if let float = Float(exactly: int) {
             return float
             }

             overflow = true
             */

        } else if let string = value as? String,
            case .convertFromString(let posInfString, let negInfString, let nanString) = self.options.nonConformingFloatUnboxStrategy {
            if string == posInfString {
                return Float.infinity
            } else if string == negInfString {
                return -Float.infinity
            } else if string == nanString {
                return Float.nan
            }
        }

        throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
    }

    fileprivate func unbox(_ value: Any, as type: Double.Type) throws -> Double? {
        
        guard !(value is NSNull) else { return nil }
        
        if let number = value as? Double {
            
            return number
            
        } else if let int = value as? Int {
            
            return Double(int)
            
        } else if let number = value as? NSNumber {
            // We are always willing to return the number as a Double:
            // * If the original value was integral, it is guaranteed to fit in a Double; we are willing to lose precision past 2^53 if you boxd a UInt64 but requested a Double
            // * If it was a Float or Double, you will get back the precise value
            // * If it was Decimal, you will get back the nearest approximation
            return number.doubleValue

            /* FIXME: If swift-corelibs-foundation doesn't change to use NSNumber, this code path will need to be included and tested:
             } else if let double = value as? Double {
             return double
             } else if let int = value as? Int {
             if let double = Double(exactly: int) {
             return double
             }

             overflow = true
             */

        } else if let string = value as? String,
            case .convertFromString(let posInfString, let negInfString, let nanString) = self.options.nonConformingFloatUnboxStrategy {
            if string == posInfString {
                return Double.infinity
            } else if string == negInfString {
                return -Double.infinity
            } else if string == nanString {
                return Double.nan
            }
        }
        
        throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
    }

    fileprivate func unbox(_ value: Any, as type: String.Type) throws -> String? {
        guard !(value is NSNull) else { return nil }

        guard let string = value as? String else {
            throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
        }

        return string
    }

    fileprivate func unbox(_ value: Any, as type: Date.Type) throws -> Date? {
        guard !(value is NSNull) else { return nil }

        switch self.options.dateUnboxStrategy {
        case .deferredToDate:
            self.storage.push(container: value)
            let date = try Date(from: self)
            self.storage.popContainer()
            return date

        case .secondsSince1970:
            let double = try self.unbox(value, as: Double.self)!
            return Date(timeIntervalSince1970: double)

        case .millisecondsSince1970:
            let double = try self.unbox(value, as: Double.self)!
            return Date(timeIntervalSince1970: double / 1000.0)

        case .iso8601:
            if #available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                #if swift(>=3.1.1)
                let string = try self.unbox(value, as: String.self)!
                guard let date = _iso8601Formatter.date(from: string) else {
                    throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Expected date string to be ISO8601-formatted."))
                }

                return date
                #else
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
                #endif
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }

        case .formatted(let formatter):
            let string = try self.unbox(value, as: String.self)!
            guard let date = formatter.date(from: string) else {
                throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Date string does not match format expected by formatter."))
            }

            return date

        case .custom(let closure):
            self.storage.push(container: value)
            let date = try closure(self)
            self.storage.popContainer()
            return date
        }
    }

    fileprivate func unbox(_ value: Any, as type: Data.Type) throws -> Data? {
        guard !(value is NSNull) else { return nil }

        switch self.options.dataUnboxStrategy {
        case .deferredToData:
            self.storage.push(container: value)
            let data = try Data(from: self)
            self.storage.popContainer()
            return data

        case .base64:
            guard let string = value as? String else {
                throw UnboxError._typeMismatch(at: self.boxingPath, expectation: type, reality: value)
            }

            guard let data = Data(base64Encoded: string) else {
                throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath, debugDescription: "Encountered Data is not valid Base64."))
            }

            return data

        case .custom(let closure):
            self.storage.push(container: value)
            let data = try closure(self)
            self.storage.popContainer()
            return data
        }
    }

    fileprivate func unbox(_ value: Any, as type: Decimal.Type) throws -> Decimal? {
        guard !(value is NSNull) else { return nil }

        // Attempt to bridge from NSDecimalNumber.
        if let decimal = value as? Decimal {
            return decimal
        } else {
            let doubleValue = try self.unbox(value, as: Double.self)!
            return Decimal(doubleValue)
        }
    }

    fileprivate func unbox<T : Unboxable>(_ value: Any, as type: T.Type) throws -> T? {
        let unboxd: T
        if T.self == Date.self {
            guard let date = try self.unbox(value, as: Date.self) else { return nil }
            unboxd = date as! T
        } else if T.self == Data.self {
            guard let data = try self.unbox(value, as: Data.self) else { return nil }
            unboxd = data as! T
        } else if T.self == URL.self {
            guard let urlString = try self.unbox(value, as: String.self) else {
                return nil
            }

            guard let url = URL(string: urlString) else {
                throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: self.boxingPath,
                                                                        debugDescription: "Invalid URL string."))
            }

            unboxd = (url as! T)
        } else if T.self == Decimal.self {
            guard let decimal = try self.unbox(value, as: Decimal.self) else { return nil }
            unboxd = decimal as! T
        } else {
            self.storage.push(container: value)
            unboxd = try T(from: self)
            self.storage.popContainer()
        }
        
        return unboxd
    }
}

//===----------------------------------------------------------------------===//
// Shared Key Types
//===----------------------------------------------------------------------===//

fileprivate struct _JSONKey : BoxingKey {
    public var stringValue: String
    public var intValue: Int?
    
    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    fileprivate init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }
    
    fileprivate static let `super` = _JSONKey(stringValue: "super")!
}

//===----------------------------------------------------------------------===//
// Shared ISO8601 Date Formatter
//===----------------------------------------------------------------------===//

// NOTE: This value is implicitly lazy and _must_ be lazy. We're compiled against the latest SDK (w/ ISO8601DateFormatter), but linked against whichever Foundation the user has. ISO8601DateFormatter might not exist, so we better not hit this code path on an older OS.
#if swift(>=3.1.1)
@available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
fileprivate var _iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()
#endif

//===----------------------------------------------------------------------===//
// Error Utilities
//===----------------------------------------------------------------------===//

fileprivate extension BoxError {
    /// Returns a `.invalidValue` error describing the given invalid floating-point value.
    ///
    ///
    /// - parameter value: The value that was invalid to box.
    /// - parameter path: The path of `BoxingKey`s taken to box this value.
    /// - returns: An `BoxError` with the appropriate path and debug description.
    fileprivate static func _invalidFloatingPointValue<T : FloatingPoint>(_ value: T, at boxingPath: [BoxingKey]) -> BoxError {
        let valueDescription: String
        if value == T.infinity {
            valueDescription = "\(T.self).infinity"
        } else if value == -T.infinity {
            valueDescription = "-\(T.self).infinity"
        } else {
            valueDescription = "\(T.self).nan"
        }
        
        let debugDescription = "Unable to box \(valueDescription) directly in JSON. Use JSONBoxer.NonConformingFloatBoxStrategy.convertToString to specify how the value should be boxd."
        return .invalidValue(value, BoxError.Context(boxingPath: boxingPath, debugDescription: debugDescription))
    }
}
