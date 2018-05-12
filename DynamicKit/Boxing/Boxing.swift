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

//===----------------------------------------------------------------------===//
// Boxing
//===----------------------------------------------------------------------===//

/// A type that can box itself to an external representation.
public protocol Boxable {
    /// Boxs this value into the given boxer.
    ///
    /// If the value fails to box anything, `boxer` will box an empty
    /// keyed container in its place.
    ///
    /// This function throws an error if any values are invalid for the given
    /// boxer's format.
    ///
    /// - Parameter boxer: The boxer to write data to.
    func box(to boxer: Boxer) throws
}

/// A type that can unbox itself from an external representation.
public protocol Unboxable {
    /// Creates a new instance by decoding from the given unboxer.
    ///
    /// This initializer throws an error if reading from the unboxer fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter unboxer: The unboxer to read data from.
    init(from unboxer: Unboxer) throws
}

/// A type that can convert itself into and out of an external representation.
public typealias Boxing = Boxable & Unboxable

//===----------------------------------------------------------------------===//
// BoxingKey
//===----------------------------------------------------------------------===//

/// A type that can be used as a key for encoding and decoding.
public protocol BoxingKey {
    /// The string to use in a named collection (e.g. a string-keyed dictionary).
    var stringValue: String { get }

    /// Initializes `self` from a string.
    ///
    /// - parameter stringValue: The string value of the desired key.
    /// - returns: An instance of `Self` from the given string, or `nil` if the given string does not correspond to any instance of `Self`.
    init?(stringValue: String)

    /// The int to use in an indexed collection (e.g. an int-keyed dictionary).
    var intValue: Int? { get }

    /// Initializes `self` from an integer.
    ///
    /// - parameter intValue: The integer value of the desired key.
    /// - returns: An instance of `Self` from the given integer, or `nil` if the given integer does not correspond to any instance of `Self`.
    init?(intValue: Int)
}


extension BoxingKey where Self: RawRepresentable, Self.RawValue == String {

    public var stringValue: String { return rawValue }

    public init?(stringValue: String) {
        self.init(rawValue: stringValue)
    }

    public var intValue: Int? { return nil }

    public init?(intValue: Int) {
        return nil
    }
}

extension BoxingKey where Self: RawRepresentable, Self.RawValue == Int {

    public var stringValue: String { return String(describing: self) }

    public init?(stringValue: String) {
        return nil
    }

    public var intValue: Int? { return rawValue }

    public init?(intValue: Int) {
        self.init(rawValue: intValue)
    }
}

//===----------------------------------------------------------------------===//
// Boxer & Unboxer
//===----------------------------------------------------------------------===//

/// A type that can box values into a native format for external representation.
public protocol Boxer {
    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var boxingPath: [BoxingKey] { get }

    /// Any contextual information set by the user for encoding.
    var userInfo: [CodingUserInfoKey : Any] { get }

    /// Returns an encoding container appropriate for holding multiple values keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A new keyed encoding container.
    /// - precondition: May not be called after a prior `self.unkeyedContainer()` call.
    /// - precondition: May not be called after a value has been boxd through a previous `self.singleValueContainer()` call.
    func container<Key>(keyedBy type: Key.Type) -> KeyedBoxingContainer<Key>

    /// Returns an encoding container appropriate for holding multiple unkeyed values.
    ///
    /// - returns: A new empty unkeyed container.
    /// - precondition: May not be called after a prior `self.container(keyedBy:)` call.
    /// - precondition: May not be called after a value has been boxd through a previous `self.singleValueContainer()` call.
    func unkeyedContainer() -> UnkeyedBoxingContainer

    /// Returns an encoding container appropriate for holding a single primitive value.
    ///
    /// - returns: A new empty single value container.
    /// - precondition: May not be called after a prior `self.container(keyedBy:)` call.
    /// - precondition: May not be called after a prior `self.unkeyedContainer()` call.
    /// - precondition: May not be called after a value has been boxd through a previous `self.singleValueContainer()` call.
    func singleValueContainer() -> SingleValueBoxingContainer
}

/// A type that can unbox values from a native format into in-memory representations.
public protocol Unboxer {
    /// The path of coding keys taken to get to this point in decoding.
    /// A `nil` value indicates an unkeyed container.
    var boxingPath: [BoxingKey] { get }

    /// Any contextual information set by the user for decoding.
    var userInfo: [CodingUserInfoKey : Any] { get }

    /// Returns the data stored in `self` as represented in a container keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `UnboxError.typeMismatch` if the encountered stored value is not a keyed container.
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedUnboxingContainer<Key>

    /// Returns the data stored in `self` as represented in a container appropriate for holding values with no keys.
    ///
    /// - returns: An unkeyed container view into `self`.
    /// - throws: `UnboxError.typeMismatch` if the encountered stored value is not an unkeyed container.
    func unkeyedContainer() throws -> UnkeyedUnboxingContainer

    /// Returns the data stored in `self` as represented in a container appropriate for holding a single primitive value.
    ///
    /// - returns: A single value container view into `self`.
    /// - throws: `UnboxError.typeMismatch` if the encountered stored value is not a single value container.
    func singleValueContainer() throws -> SingleValueUnboxingContainer
}

//===----------------------------------------------------------------------===//
// Keyed Box Containers
//===----------------------------------------------------------------------===//

/// A type that provides a view into an boxer's storage and is used to hold
/// the boxd properties of an encodable type in a keyed manner.
///
/// Boxers should provide types conforming to
/// `KeyedBoxingContainerProtocol` for their format.
public protocol KeyedBoxingContainerProtocol {
    associatedtype Key : BoxingKey

    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var boxingPath: [BoxingKey] { get }

    /// Boxs a null value for the given key.
    ///
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if a null value is invalid in the current context for this format.
    mutating func boxNil(forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Bool, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int8, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int16, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int32, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int64, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt8, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt16, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt32, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt64, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Float, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Double, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: String, forKey key: Key) throws

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box<T : Boxable>(_ value: T, forKey key: Key) throws

    /// Boxs a reference to the given object only if it is boxd unconditionally elsewhere in the payload (previously, or in the future).
    ///
    /// For `Boxer`s which don't support this feature, the default implementation boxs the given object unconditionally.
    ///
    /// - parameter object: The object to box.
    /// - parameter key: The key to associate the object with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxConditional<T : AnyObject & Boxable>(_ object: T, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: Bool?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: Int?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: Int8?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: Int16?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: Int32?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: Int64?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: UInt?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: UInt8?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: UInt16?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: UInt32?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: UInt64?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: Float?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: Double?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent(_ value: String?, forKey key: Key) throws

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxIfPresent<T : Boxable>(_ value: T?, forKey key: Key) throws

    /// Stores a keyed encoding container for the given key and returns it.
    ///
    /// - parameter keyType: The key type to use for the container.
    /// - parameter key: The key to box the container for.
    /// - returns: A new keyed encoding container.
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedBoxingContainer<NestedKey>

    /// Stores an unkeyed encoding container for the given key and returns it.
    ///
    /// - parameter key: The key to box the container for.
    /// - returns: A new unkeyed encoding container.
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedBoxingContainer

    /// Stores a new nested container for the default `super` key and returns a new `Boxer` instance for encoding `super` into that container.
    ///
    /// Equivalent to calling `superBoxer(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new `Boxer` to pass to `super.box(to:)`.
    mutating func superBoxer() -> Boxer

    /// Stores a new nested container for the given key and returns a new `Boxer` instance for encoding `super` into that container.
    ///
    /// - parameter key: The key to box `super` for.
    /// - returns: A new `Boxer` to pass to `super.box(to:)`.
    mutating func superBoxer(forKey key: Key) -> Boxer
}

// An implementation of _KeyedBoxingContainerBase and _KeyedBoxingContainerBox are given at the bottom of this file.

/// A concrete container that provides a view into an boxer's storage, making
/// the boxd properties of an encodable type accessible by keys.
public struct KeyedBoxingContainer<K : BoxingKey> : KeyedBoxingContainerProtocol {
    public typealias Key = K

    /// The container for the concrete boxer. The type is _*Base so that it's generic on the key type.
    @_versioned
    internal var _box: _KeyedBoxingContainerBase<Key>

    /// Initializes `self` with the given container.
    ///
    /// - parameter container: The container to hold.
    public init<Container : KeyedBoxingContainerProtocol>(_ container: Container) where Container.Key == Key {
        _box = _KeyedBoxingContainerBox(container)
    }

    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    public var boxingPath: [BoxingKey] {
        return _box.boxingPath
    }

    /// Boxs a null value for the given key.
    ///
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if a null value is invalid in the current context for this format.
    public mutating func boxNil(forKey key: Key) throws {
        try _box.boxNil(forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: Bool, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: Int, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: Int8, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: Int16, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: Int32, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: Int64, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: UInt, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: UInt8, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: UInt16, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: UInt32, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: UInt64, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: Float, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: Double, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box(_ value: String, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs the given value for the given key.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func box<T : Boxable>(_ value: T, forKey key: Key) throws {
        try _box.box(value, forKey: key)
    }

    /// Boxs a reference to the given object only if it is boxd unconditionally elsewhere in the payload (previously, or in the future).
    ///
    /// For `Boxer`s which don't support this feature, the default implementation boxs the given object unconditionally.
    ///
    /// - parameter object: The object to box.
    /// - parameter key: The key to associate the object with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxConditional<T : AnyObject & Boxable>(_ object: T, forKey key: Key) throws {
        try _box.boxConditional(object, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: Bool?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: Int?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: Int8?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: Int16?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: Int32?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: Int64?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: UInt?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: UInt8?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: UInt16?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: UInt32?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: UInt64?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: Float?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: Double?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent(_ value: String?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Boxs the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to box.
    /// - parameter key: The key to associate the value with.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    public mutating func boxIfPresent<T : Boxable>(_ value: T?, forKey key: Key) throws {
        try _box.boxIfPresent(value, forKey: key)
    }

    /// Stores a keyed encoding container for the given key and returns it.
    ///
    /// - parameter keyType: The key type to use for the container.
    /// - parameter key: The key to box the container for.
    /// - returns: A new keyed encoding container.
    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedBoxingContainer<NestedKey> {
        return _box.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }

    /// Stores an unkeyed encoding container for the given key and returns it.
    ///
    /// - parameter key: The key to box the container for.
    /// - returns: A new unkeyed encoding container.
    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedBoxingContainer {
        return _box.nestedUnkeyedContainer(forKey: key)
    }

    /// Stores a new nested container for the default `super` key and returns a new `Boxer` instance for encoding `super` into that container.
    ///
    /// Equivalent to calling `superBoxer(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new `Boxer` to pass to `super.box(to:)`.
    public mutating func superBoxer() -> Boxer {
        return _box.superBoxer()
    }

    /// Stores a new nested container for the given key and returns a new `Boxer` instance for encoding `super` into that container.
    ///
    /// - parameter key: The key to box `super` for.
    /// - returns: A new `Boxer` to pass to `super.box(to:)`.
    public mutating func superBoxer(forKey key: Key) -> Boxer {
        return _box.superBoxer(forKey: key)
    }
}

/// A type that provides a view into a unboxer's storage and is used to hold
/// the boxd properties of a decodable type in a keyed manner.
///
/// Unboxers should provide types conforming to `UnkeyedUnboxingContainer` for
/// their format.
public protocol KeyedUnboxingContainerProtocol {
    associatedtype Key : BoxingKey

    /// The path of coding keys taken to get to this point in decoding.
    /// A `nil` value indicates an unkeyed container.
    var boxingPath: [BoxingKey] { get }

    /// All the keys the `Unboxer` has for this container.
    ///
    /// Different keyed containers from the same `Unboxer` may return different keys here; it is possible to box with multiple key types which are not convertible to one another. This should report all keys present which are convertible to the requested type.
    var allKeys: [Key] { get }

    /// Returns whether the `Unboxer` contains a value associated with the given key.
    ///
    /// The value associated with the given key may be a null value as appropriate for the data format.
    ///
    /// - parameter key: The key to search for.
    /// - returns: Whether the `Unboxer` has an entry for the given key.
    func contains(_ key: Key) -> Bool

    /// Unboxs a null value for the given key.
    ///
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: Whether the encountered value was null.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    func unboxNil(forKey key: Key) throws -> Bool

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: Bool.Type, forKey key: Key) throws -> Bool

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: Int.Type, forKey key: Key) throws -> Int

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: Int8.Type, forKey key: Key) throws -> Int8

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: Int16.Type, forKey key: Key) throws -> Int16

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: Int32.Type, forKey key: Key) throws -> Int32

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: Int64.Type, forKey key: Key) throws -> Int64

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: UInt.Type, forKey key: Key) throws -> UInt

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: UInt8.Type, forKey key: Key) throws -> UInt8

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: UInt16.Type, forKey key: Key) throws -> UInt16

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: UInt32.Type, forKey key: Key) throws -> UInt32

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: UInt64.Type, forKey key: Key) throws -> UInt64

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: Float.Type, forKey key: Key) throws -> Float

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: Double.Type, forKey key: Key) throws -> Double

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox(_ type: String.Type, forKey key: Key) throws -> String

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func unbox<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent(_ type: String.Type, forKey key: Key) throws -> String?

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    func unboxIfPresent<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T?

    /// Returns the data stored for the given key as represented in a container keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `UnboxError.typeMismatch` if the encountered stored value is not a keyed container.
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedUnboxingContainer<NestedKey>

    /// Returns the data stored for the given key as represented in an unkeyed container.
    ///
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `UnboxError.typeMismatch` if the encountered stored value is not an unkeyed container.
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedUnboxingContainer

    /// Returns a `Unboxer` instance for decoding `super` from the container associated with the default `super` key.
    ///
    /// Equivalent to calling `superUnboxer(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new `Unboxer` to pass to `super.init(from:)`.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the default `super` key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the default `super` key.
    func superUnboxer() throws -> Unboxer

    /// Returns a `Unboxer` instance for decoding `super` from the container associated with the given key.
    ///
    /// - parameter key: The key to unbox `super` for.
    /// - returns: A new `Unboxer` to pass to `super.init(from:)`.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    func superUnboxer(forKey key: Key) throws -> Unboxer
}

// An implementation of _KeyedUnboxingContainerBase and _KeyedUnboxingContainerBox are given at the bottom of this file.

/// A concrete container that provides a view into an unboxer's storage, making
/// the boxd properties of an decodable type accessible by keys.
public struct KeyedUnboxingContainer<K : BoxingKey> : KeyedUnboxingContainerProtocol {
    public typealias Key = K

    /// The container for the concrete unboxer. The type is _*Base so that it's generic on the key type.
    @_versioned
    internal var _box: _KeyedUnboxingContainerBase<Key>

    /// Initializes `self` with the given container.
    ///
    /// - parameter container: The container to hold.
    public init<Container : KeyedUnboxingContainerProtocol>(_ container: Container) where Container.Key == Key {
        _box = _KeyedUnboxingContainerBox(container)
    }

    /// The path of coding keys taken to get to this point in decoding.
    /// A `nil` value indicates an unkeyed container.
    public var boxingPath: [BoxingKey] {
        return _box.boxingPath
    }

    /// All the keys the `Unboxer` has for this container.
    ///
    /// Different keyed containers from the same `Unboxer` may return different keys here; it is possible to box with multiple key types which are not convertible to one another. This should report all keys present which are convertible to the requested type.
    public var allKeys: [Key] {
        return _box.allKeys
    }

    /// Returns whether the `Unboxer` contains a value associated with the given key.
    ///
    /// The value associated with the given key may be a null value as appropriate for the data format.
    ///
    /// - parameter key: The key to search for.
    /// - returns: Whether the `Unboxer` has an entry for the given key.
    public func contains(_ key: Key) -> Bool {
        return _box.contains(key)
    }

    /// Unboxs a null value for the given key.
    ///
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: Whether the encountered value was null.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    public func unboxNil(forKey key: Key) throws -> Bool {
        return try _box.unboxNil(forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try _box.unbox(Bool.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try _box.unbox(Int.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try _box.unbox(Int8.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try _box.unbox(Int16.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try _box.unbox(Int32.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try _box.unbox(Int64.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try _box.unbox(UInt.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try _box.unbox(UInt8.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try _box.unbox(UInt16.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try _box.unbox(UInt32.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try _box.unbox(UInt64.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try _box.unbox(Float.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try _box.unbox(Double.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox(_ type: String.Type, forKey key: Key) throws -> String {
        return try _box.unbox(String.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func unbox<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T {
        return try _box.unbox(T.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        return try _box.unboxIfPresent(Bool.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        return try _box.unboxIfPresent(Int.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        return try _box.unboxIfPresent(Int8.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        return try _box.unboxIfPresent(Int16.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        return try _box.unboxIfPresent(Int32.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        return try _box.unboxIfPresent(Int64.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        return try _box.unboxIfPresent(UInt.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        return try _box.unboxIfPresent(UInt8.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        return try _box.unboxIfPresent(UInt16.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        return try _box.unboxIfPresent(UInt32.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        return try _box.unboxIfPresent(UInt64.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        return try _box.unboxIfPresent(Float.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        return try _box.unboxIfPresent(Double.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        return try _box.unboxIfPresent(String.self, forKey: key)
    }

    /// Unboxs a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value associated with `key`, or if the value is null. The difference between these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to unbox.
    /// - parameter key: The key that the unboxd value is associated with.
    /// - returns: A unboxd value of the requested type, or `nil` if the `Unboxer` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    public func unboxIfPresent<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T? {
        return try _box.unboxIfPresent(T.self, forKey: key)
    }

    /// Returns the data stored for the given key as represented in a container keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `UnboxError.typeMismatch` if the encountered stored value is not a keyed container.
    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedUnboxingContainer<NestedKey> {
        return try _box.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }

    /// Returns the data stored for the given key as represented in an unkeyed container.
    ///
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `UnboxError.typeMismatch` if the encountered stored value is not an unkeyed container.
    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedUnboxingContainer {
        return try _box.nestedUnkeyedContainer(forKey: key)
    }

    /// Returns a `Unboxer` instance for decoding `super` from the container associated with the default `super` key.
    ///
    /// Equivalent to calling `superUnboxer(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the default `super` key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the default `super` key.
    public func superUnboxer() throws -> Unboxer {
        return try _box.superUnboxer()
    }

    /// Returns a `Unboxer` instance for decoding `super` from the container associated with the given key.
    ///
    /// - parameter key: The key to unbox `super` for.
    /// - returns: A new `Unboxer` to pass to `super.init(from:)`.
    /// - throws: `UnboxError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `UnboxError.valueNotFound` if `self` has a null entry for the given key.
    public func superUnboxer(forKey key: Key) throws -> Unboxer {
        return try _box.superUnboxer(forKey: key)
    }
}

//===----------------------------------------------------------------------===//
// Unkeyed Box Containers
//===----------------------------------------------------------------------===//

/// A type that provides a view into an boxer's storage and is used to hold
/// the boxd properties of an encodable type sequentially, without keys.
///
/// Boxers should provide types conforming to `UnkeyedBoxingContainer` for
/// their format.
public protocol UnkeyedBoxingContainer {
    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var boxingPath: [BoxingKey] { get }

    /// The number of elements boxd into the container.
    var count: Int { get }

    /// Boxs a null value.
    ///
    /// - throws: `BoxError.invalidValue` if a null value is invalid in the current context for this format.
    mutating func boxNil() throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Bool) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int8) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int16) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int32) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Int64) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt8) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt16) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt32) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: UInt64) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Float) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: Double) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box(_ value: String) throws

    /// Boxs the given value.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func box<T : Boxable>(_ value: T) throws

    /// Boxs a reference to the given object only if it is boxd unconditionally elsewhere in the payload (previously, or in the future).
    ///
    /// For `Boxer`s which don't support this feature, the default implementation boxs the given object unconditionally.
    ///
    /// For formats which don't support this feature, the default implementation boxs the given object unconditionally.
    ///
    /// - parameter object: The object to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func boxConditional<T : AnyObject & Boxable>(_ object: T) throws

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Bool

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int8

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int16

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int32

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int64

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt8

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt16

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt32

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt64

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Float

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Double

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == String

    /// Boxs the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to box.
    /// - throws: An error if any of the contained values throws an error.
    mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element : Boxable

    /// Boxs a nested container keyed by the given type and returns it.
    ///
    /// - parameter keyType: The key type to use for the container.
    /// - returns: A new keyed encoding container.
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedBoxingContainer<NestedKey>

    /// Boxs an unkeyed encoding container and returns it.
    ///
    /// - returns: A new unkeyed encoding container.
    mutating func nestedUnkeyedContainer() -> UnkeyedBoxingContainer

    /// Boxs a nested container and returns an `Boxer` instance for encoding `super` into that container.
    ///
    /// - returns: A new `Boxer` to pass to `super.box(to:)`.
    mutating func superBoxer() -> Boxer
}

/// A type that provides a view into a unboxer's storage and is used to hold
/// the boxd properties of a decodable type sequentially, without keys.
///
/// Unboxers should provide types conforming to `UnkeyedUnboxingContainer` for
/// their format.
public protocol UnkeyedUnboxingContainer {
    /// The path of coding keys taken to get to this point in decoding.
    /// A `nil` value indicates an unkeyed container.
    var boxingPath: [BoxingKey] { get }

    /// Returns the number of elements (if known) contained within this container.
    var count: Int? { get }

    /// Returns whether there are no more elements left to be unboxd in the container.
    var isAtEnd: Bool { get }

    /// The current decoding index of the container (i.e. the index of the next element to be unboxd.)
    /// Incremented after every successful unbox call.
    var currentIndex: Int { get }

    /// Unboxs a null value.
    ///
    /// If the value is not null, does not increment currentIndex.
    ///
    /// - returns: Whether the encountered value was null.
    /// - throws: `UnboxError.valueNotFound` if there are no more values to unbox.
    mutating func unboxNil() throws -> Bool

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: Bool.Type) throws -> Bool

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: Int.Type) throws -> Int

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: Int8.Type) throws -> Int8

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: Int16.Type) throws -> Int16

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: Int32.Type) throws -> Int32

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: Int64.Type) throws -> Int64

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: UInt.Type) throws -> UInt

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: UInt8.Type) throws -> UInt8

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: UInt16.Type) throws -> UInt16

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: UInt32.Type) throws -> UInt32

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: UInt64.Type) throws -> UInt64

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: Float.Type) throws -> Float

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: Double.Type) throws -> Double

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox(_ type: String.Type) throws -> String

    /// Unboxs a value of the given type.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func unbox<T : Unboxable>(_ type: T.Type) throws -> T

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: Bool.Type) throws -> Bool?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: Int.Type) throws -> Int?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: Int8.Type) throws -> Int8?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: Int16.Type) throws -> Int16?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: Int32.Type) throws -> Int32?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: Int64.Type) throws -> Int64?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: UInt.Type) throws -> UInt?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: UInt8.Type) throws -> UInt8?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: UInt16.Type) throws -> UInt16?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: UInt32.Type) throws -> UInt32?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: UInt64.Type) throws -> UInt64?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: Float.Type) throws -> Float?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: Double.Type) throws -> Double?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent(_ type: String.Type) throws -> String?

    /// Unboxs a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to unbox, or if the value is null. The difference between these states can be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to unbox.
    /// - returns: A unboxd value of the requested type, or `nil` if the value is a null value, or if there are no more elements to unbox.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value is not convertible to the requested type.
    mutating func unboxIfPresent<T : Unboxable>(_ type: T.Type) throws -> T?

    /// Unboxs a nested container keyed by the given type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `UnboxError.typeMismatch` if the encountered stored value is not a keyed container.
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedUnboxingContainer<NestedKey>

    /// Unboxs an unkeyed nested container.
    ///
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `UnboxError.typeMismatch` if the encountered stored value is not an unkeyed container.
    mutating func nestedUnkeyedContainer() throws -> UnkeyedUnboxingContainer

    /// Unboxs a nested container and returns a `Unboxer` instance for decoding `super` from that container.
    ///
    /// - returns: A new `Unboxer` to pass to `super.init(from:)`.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null, or of there are no more values to unbox.
    mutating func superUnboxer() throws -> Unboxer
}

//===----------------------------------------------------------------------===//
// Single Value Box Containers
//===----------------------------------------------------------------------===//

/// A container that can support the storage and direct encoding of a single
/// non-keyed value.
public protocol SingleValueBoxingContainer {
    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var boxingPath: [BoxingKey] { get }

    /// Boxs a null value.
    ///
    /// - throws: `BoxError.invalidValue` if a null value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func boxNil() throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: Bool) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: Int) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: Int8) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: Int16) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: Int32) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: Int64) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: UInt) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: UInt8) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: UInt16) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: UInt32) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: UInt64) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: Float) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: Double) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box(_ value: String) throws

    /// Boxs a single value of the given type.
    ///
    /// - parameter value: The value to box.
    /// - throws: `BoxError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.box(_:)` call.
    mutating func box<T : Boxable>(_ value: T) throws
}

/// A `SingleValueUnboxingContainer` is a container which can support the storage and direct decoding of a single non-keyed value.
public protocol SingleValueUnboxingContainer {
    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var boxingPath: [BoxingKey] { get }

    /// Unboxs a null value.
    ///
    /// - returns: Whether the encountered value was null.
    func unboxNil() -> Bool

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: Bool.Type) throws -> Bool

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: Int.Type) throws -> Int

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: Int8.Type) throws -> Int8

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: Int16.Type) throws -> Int16

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: Int32.Type) throws -> Int32

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: Int64.Type) throws -> Int64

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: UInt.Type) throws -> UInt

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: UInt8.Type) throws -> UInt8

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: UInt16.Type) throws -> UInt16

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: UInt32.Type) throws -> UInt32

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: UInt64.Type) throws -> UInt64

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: Float.Type) throws -> Float

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: Double.Type) throws -> Double

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox(_ type: String.Type) throws -> String

    /// Unboxs a single value of the given type.
    ///
    /// - parameter type: The type to unbox as.
    /// - returns: A value of the requested type.
    /// - throws: `UnboxError.typeMismatch` if the encountered boxd value cannot be converted to the requested type.
    /// - throws: `UnboxError.valueNotFound` if the encountered boxd value is null.
    func unbox<T : Unboxable>(_ type: T.Type) throws -> T
}

//===----------------------------------------------------------------------===//
// User Info
//===----------------------------------------------------------------------===//

/// A user-defined key for providing context during encoding and decoding.
public struct CodingUserInfoKey : RawRepresentable, Equatable, Hashable {
    public typealias RawValue = String

    /// The key's string value.
    public let rawValue: String

    /// Initializes `self` with the given raw value.
    ///
    /// - parameter rawValue: The value of the key.
    public init?(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Returns whether the given keys are equal.
    ///
    /// - parameter lhs: The key to compare against.
    /// - parameter rhs: The key to compare with.
    public static func ==(_ lhs: CodingUserInfoKey, _ rhs: CodingUserInfoKey) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    /// The key's hash value.
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
}

//===----------------------------------------------------------------------===//
// Errors
//===----------------------------------------------------------------------===//

/// An error that occurs during the encoding of a value.
public enum BoxError : Error {
    /// The context in which the error occurred.
    public struct Context {
        /// The path of `BoxingKey`s taken to get to the point of the failing box call.
        public let boxingPath: [BoxingKey]

        /// A description of what went wrong, for debugging purposes.
        public let debugDescription: String

        /// The underlying error which caused this error, if any.
        public let underlyingError: Error?

        /// Initializes `self` with the given path of `BoxingKey`s and a description of what went wrong.
        ///
        /// - parameter boxingPath: The path of `BoxingKey`s taken to get to the point of the failing box call.
        /// - parameter debugDescription: A description of what went wrong, for debugging purposes.
        /// - parameter underlyingError: The underlying error which caused this error, if any.
        public init(boxingPath: [BoxingKey], debugDescription: String, underlyingError: Error? = nil) {
            self.boxingPath = boxingPath
            self.debugDescription = debugDescription
            self.underlyingError = underlyingError
        }
    }

    /// `.invalidValue` indicates that an `Boxer` or its containers could not box the given value.
    ///
    /// Contains the attempted value, along with context for debugging.
    case invalidValue(Any, Context)

    // MARK: - NSError Bridging

    // CustomNSError bridging applies only when the CustomNSError conformance is applied in the same module as the declared error type.
    // Since we cannot access CustomNSError (which is defined in Foundation) from here, we can use the "hidden" entry points.

    public var _domain: String {
        return "NSCocoaErrorDomain"
    }

    public var _code: Int {
        switch self {
        case .invalidValue(_, _): return 4866
        }
    }

    public var _userInfo: AnyObject? {
        // The error dictionary must be returned as an AnyObject. We can do this only on platforms with bridging, unfortunately.
        #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            let context: Context
            switch self {
            case .invalidValue(_, let c): context = c
            }

            var userInfo: [String : Any] = [
                "NSCodingPath": context.boxingPath,
                "NSDebugDescription": context.debugDescription
            ]

            if let underlyingError = context.underlyingError {
                userInfo["NSUnderlyingError"] = underlyingError
            }

            return userInfo as AnyObject
        #else
            return nil
        #endif
    }
}

/// An error that occurs during the decoding of a value.
public enum UnboxError : Error {
    /// The context in which the error occurred.
    public struct Context {
        /// The path of `BoxingKey`s taken to get to the point of the failing unbox call.
        public let boxingPath: [BoxingKey]

        /// A description of what went wrong, for debugging purposes.
        public let debugDescription: String

        /// The underlying error which caused this error, if any.
        public let underlyingError: Error?

        /// Initializes `self` with the given path of `BoxingKey`s and a description of what went wrong.
        ///
        /// - parameter boxingPath: The path of `BoxingKey`s taken to get to the point of the failing unbox call.
        /// - parameter debugDescription: A description of what went wrong, for debugging purposes.
        /// - parameter underlyingError: The underlying error which caused this error, if any.
        public init(boxingPath: [BoxingKey], debugDescription: String, underlyingError: Error? = nil) {
            self.boxingPath = boxingPath
            self.debugDescription = debugDescription
            self.underlyingError = underlyingError
        }
    }

    /// `.typeMismatch` indicates that a value of the given type could not be unboxd because it did not match the type of what was found in the boxd payload.
    ///
    /// Contains the attempted type, along with context for debugging.
    case typeMismatch(Any.Type, Context)

    /// `.valueNotFound` indicates that a non-optional value of the given type was expected, but a null value was found.
    ///
    /// Contains the attempted type, along with context for debugging.
    case valueNotFound(Any.Type, Context)

    /// `.keyNotFound` indicates that a `KeyedUnboxingContainer` was asked for an entry for the given key, but did not contain one.
    ///
    /// Contains the attempted key, along with context for debugging.
    case keyNotFound(BoxingKey, Context)

    /// `.dataCorrupted` indicates that the data is corrupted or otherwise invalid.
    ///
    /// Contains context for debugging.
    case dataCorrupted(Context)

    // MARK: - NSError Bridging

    // CustomNSError bridging applies only when the CustomNSError conformance is applied in the same module as the declared error type.
    // Since we cannot access CustomNSError (which is defined in Foundation) from here, we can use the "hidden" entry points.

    public var _domain: String {
        return "NSCocoaErrorDomain"
    }

    public var _code: Int {
        switch self {
        case .keyNotFound(_, _):   fallthrough
        case .valueNotFound(_, _): return 4865
        case .typeMismatch(_, _):  fallthrough
        case .dataCorrupted(_):    return 4864
        }
    }

    public var _userInfo: AnyObject? {
        // The error dictionary must be returned as an AnyObject. We can do this only on platforms with bridging, unfortunately.
        #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            let context: Context
            switch self {
            case .keyNotFound(_,   let c): context = c
            case .valueNotFound(_, let c): context = c
            case .typeMismatch(_,  let c): context = c
            case .dataCorrupted(   let c): context = c
            }

            var userInfo: [String : Any] = [
                "NSCodingPath": context.boxingPath,
                "NSDebugDescription": context.debugDescription
            ]

            if let underlyingError = context.underlyingError {
                userInfo["NSUnderlyingError"] = underlyingError
            }

            return userInfo as AnyObject
        #else
            return nil
        #endif
    }
}

// The following extensions allow for easier error construction.

internal struct _GenericIndexKey : BoxingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        return nil
    }

    init?(intValue: Int) {
        self.stringValue = "Index \(intValue)"
        self.intValue = intValue
    }
}

public extension UnboxError {
    /// A convenience method which creates a new .dataCorrupted error using a constructed coding path and the given debug description.
    ///
    /// Constructs a coding path by appending the given key to the given container's coding path.
    ///
    /// - param key: The key which caused the failure.
    /// - param container: The container in which the corrupted data was accessed.
    /// - param debugDescription: A description of the error to aid in debugging.
    static func dataCorruptedError<C : KeyedUnboxingContainerProtocol>(forKey key: C.Key, in container: C, debugDescription: String) -> UnboxError {
        let context = UnboxError.Context(boxingPath: container.boxingPath + [key],
                                            debugDescription: debugDescription)
        return .dataCorrupted(context)
    }

    /// A convenience method which creates a new .dataCorrupted error using a constructed coding path and the given debug description.
    ///
    /// Constructs a coding path by appending a nil key to the given container's coding path.
    ///
    /// - param container: The container in which the corrupted data was accessed.
    /// - param debugDescription: A description of the error to aid in debugging.
    static func dataCorruptedError(in container: UnkeyedUnboxingContainer, debugDescription: String) -> UnboxError {
        let context = UnboxError.Context(boxingPath: container.boxingPath + [_GenericIndexKey(intValue: container.currentIndex)!],
                                            debugDescription: debugDescription)
        return .dataCorrupted(context)
    }

    /// A convenience method which creates a new .dataCorrupted error using a constructed coding path and the given debug description.
    ///
    /// Uses the given container's coding path as the constructed path.
    ///
    /// - param container: The container in which the corrupted data was accessed.
    /// - param debugDescription: A description of the error to aid in debugging.
    static func dataCorruptedError(in container: SingleValueUnboxingContainer, debugDescription: String) -> UnboxError {
        let context = UnboxError.Context(boxingPath: container.boxingPath,
                                            debugDescription: debugDescription)
        return .dataCorrupted(context)
    }
}

//===----------------------------------------------------------------------===//
// Keyed Box Container Implementations
//===----------------------------------------------------------------------===//

@_fixed_layout
@_versioned
internal class _KeyedBoxingContainerBase<Key : BoxingKey> {
    // These must all be given a concrete implementation in _*Box.
    
    @_versioned
    internal var boxingPath: [BoxingKey] {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxNil(forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: Bool, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: Int, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: Int8, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: Int16, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: Int32, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: Int64, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: UInt, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: UInt8, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: UInt16, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: UInt32, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: UInt64, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: Float, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: Double, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box(_ value: String, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func box<T : Boxable>(_ value: T, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxConditional<T : AnyObject & Boxable>(_ object: T, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: Bool?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: Int?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: Int8?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: Int16?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: Int32?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: Int64?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: UInt?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: UInt8?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: UInt16?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: UInt32?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: UInt64?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: Float?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: Double?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent(_ value: String?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func boxIfPresent<T : Boxable>(_ value: T?, forKey key: Key) throws {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedBoxingContainer<NestedKey> {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedBoxingContainer {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func superBoxer() -> Boxer {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func superBoxer(forKey key: Key) -> Boxer {
        fatalError("_KeyedBoxingContainerBase cannot be used directly.")
    }
}

@_fixed_layout
@_versioned
internal final class _KeyedBoxingContainerBox<Concrete : KeyedBoxingContainerProtocol> : _KeyedBoxingContainerBase<Concrete.Key> {
    typealias Key = Concrete.Key

    @_versioned
    internal var concrete: Concrete

    
    @_versioned
    internal init(_ container: Concrete) {
        concrete = container
    }

    
    @_versioned
    override internal var boxingPath: [BoxingKey] {
        return concrete.boxingPath
    }

    
    @_versioned
    override internal func boxNil(forKey key: Key) throws {
        try concrete.boxNil(forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: Bool, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: Int, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: Int8, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: Int16, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: Int32, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: Int64, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: UInt, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: UInt8, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: UInt16, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: UInt32, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: UInt64, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: Float, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: Double, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box(_ value: String, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func box<T : Boxable>(_ value: T, forKey key: Key) throws {
        try concrete.box(value, forKey: key)
    }

    
    @_versioned
    override internal func boxConditional<T : AnyObject & Boxable>(_ object: T, forKey key: Key) throws {
        try concrete.boxConditional(object, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: Bool?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: Int?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: Int8?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: Int16?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: Int32?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: Int64?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: UInt?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: UInt8?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: UInt16?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: UInt32?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: UInt64?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: Float?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: Double?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent(_ value: String?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func boxIfPresent<T : Boxable>(_ value: T?, forKey key: Key) throws {
        try concrete.boxIfPresent(value, forKey: key)
    }

    
    @_versioned
    override internal func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedBoxingContainer<NestedKey> {
        return concrete.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }

    
    @_versioned
    override internal func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedBoxingContainer {
        return concrete.nestedUnkeyedContainer(forKey: key)
    }

    
    @_versioned
    override internal func superBoxer() -> Boxer {
        return concrete.superBoxer()
    }

    
    @_versioned
    override internal func superBoxer(forKey key: Key) -> Boxer {
        return concrete.superBoxer(forKey: key)
    }
}

@_fixed_layout
@_versioned
internal class _KeyedUnboxingContainerBase<Key : BoxingKey> {
    
    @_versioned
    internal var boxingPath: [BoxingKey] {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal var allKeys: [Key] {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func contains(_ key: Key) -> Bool {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxNil(forKey key: Key) throws -> Bool {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: Int.Type, forKey key: Key) throws -> Int {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: Float.Type, forKey key: Key) throws -> Float {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: Double.Type, forKey key: Key) throws -> Double {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox(_ type: String.Type, forKey key: Key) throws -> String {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unbox<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func unboxIfPresent<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T? {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedUnboxingContainer<NestedKey> {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedUnboxingContainer {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func superUnboxer() throws -> Unboxer {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }

    
    @_versioned
    internal func superUnboxer(forKey key: Key) throws -> Unboxer {
        fatalError("_KeyedUnboxingContainerBase cannot be used directly.")
    }
}

@_fixed_layout
@_versioned
internal final class _KeyedUnboxingContainerBox<Concrete : KeyedUnboxingContainerProtocol> : _KeyedUnboxingContainerBase<Concrete.Key> {
    typealias Key = Concrete.Key

    @_versioned
    internal var concrete: Concrete

    
    @_versioned
    internal init(_ container: Concrete) {
        concrete = container
    }

    
    @_versioned
    override var boxingPath: [BoxingKey] {
        return concrete.boxingPath
    }

    
    @_versioned
    override var allKeys: [Key] {
        return concrete.allKeys
    }

    
    @_versioned
    override internal func contains(_ key: Key) -> Bool {
        return concrete.contains(key)
    }

    
    @_versioned
    override internal func unboxNil(forKey key: Key) throws -> Bool {
        return try concrete.unboxNil(forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try concrete.unbox(Bool.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try concrete.unbox(Int.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try concrete.unbox(Int8.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try concrete.unbox(Int16.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try concrete.unbox(Int32.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try concrete.unbox(Int64.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try concrete.unbox(UInt.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try concrete.unbox(UInt8.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try concrete.unbox(UInt16.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try concrete.unbox(UInt32.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try concrete.unbox(UInt64.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try concrete.unbox(Float.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try concrete.unbox(Double.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox(_ type: String.Type, forKey key: Key) throws -> String {
        return try concrete.unbox(String.self, forKey: key)
    }

    
    @_versioned
    override internal func unbox<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T {
        return try concrete.unbox(T.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        return try concrete.unboxIfPresent(Bool.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        return try concrete.unboxIfPresent(Int.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        return try concrete.unboxIfPresent(Int8.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        return try concrete.unboxIfPresent(Int16.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        return try concrete.unboxIfPresent(Int32.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        return try concrete.unboxIfPresent(Int64.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        return try concrete.unboxIfPresent(UInt.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        return try concrete.unboxIfPresent(UInt8.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        return try concrete.unboxIfPresent(UInt16.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        return try concrete.unboxIfPresent(UInt32.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        return try concrete.unboxIfPresent(UInt64.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        return try concrete.unboxIfPresent(Float.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        return try concrete.unboxIfPresent(Double.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        return try concrete.unboxIfPresent(String.self, forKey: key)
    }

    
    @_versioned
    override internal func unboxIfPresent<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T? {
        return try concrete.unboxIfPresent(T.self, forKey: key)
    }

    
    @_versioned
    override internal func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedUnboxingContainer<NestedKey> {
        return try concrete.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }

    
    @_versioned
    override internal func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedUnboxingContainer {
        return try concrete.nestedUnkeyedContainer(forKey: key)
    }

    
    @_versioned
    override internal func superUnboxer() throws -> Unboxer {
        return try concrete.superUnboxer()
    }

    
    @_versioned
    override internal func superUnboxer(forKey key: Key) throws -> Unboxer {
        return try concrete.superUnboxer(forKey: key)
    }
}

//===----------------------------------------------------------------------===//
// Primitive and RawRepresentable Extensions
//===----------------------------------------------------------------------===//

extension Bool : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(Bool.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension Int : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(Int.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension Int8 : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(Int8.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension Int16 : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(Int16.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension Int32 : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(Int32.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension Int64 : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(Int64.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension UInt : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(UInt.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension UInt8 : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(UInt8.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension UInt16 : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(UInt16.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension UInt32 : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(UInt32.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension UInt64 : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(UInt64.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension Float : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(Float.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension Double : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(Double.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

extension String : Boxing {
    public init(from unboxer: Unboxer) throws {
        self = try unboxer.singleValueContainer().unbox(String.self)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self)
    }
}

public extension RawRepresentable where RawValue == Bool, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Bool, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == Int, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == Int8, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int8, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == Int16, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int16, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == Int32, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int32, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == Int64, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Int64, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == UInt, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == UInt8, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt8, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == UInt16, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt16, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == UInt32, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt32, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == UInt64, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == UInt64, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == Float, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Float, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == Double, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == Double, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

public extension RawRepresentable where RawValue == String, Self : Boxable {
    public func box(to boxer: Boxer) throws {
        var container = boxer.singleValueContainer()
        try container.box(self.rawValue)
    }
}

public extension RawRepresentable where RawValue == String, Self : Unboxable {
    public init(from unboxer: Unboxer) throws {
        let unboxd = try unboxer.singleValueContainer().unbox(RawValue.self)
        guard let value = Self(rawValue: unboxd) else {
            throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath, debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(unboxd)"))
        }

        self = value
    }
}

//===----------------------------------------------------------------------===//
// Optional/Collection Type Conformances
//===----------------------------------------------------------------------===//

fileprivate func assertTypeIsEncodable<T>(_ type: T.Type, in wrappingType: Any.Type) {
    guard T.self is Boxable.Type else {
        if T.self == Boxable.self || T.self == Boxing.self {
            preconditionFailure("\(wrappingType) does not conform to Boxable because Boxable does not conform to itself. You must use a concrete type to box or unbox.")
        } else {
            preconditionFailure("\(wrappingType) does not conform to Boxable because \(T.self) does not conform to Boxable.")
        }
    }
}

fileprivate func assertTypeIsDecodable<T>(_ type: T.Type, in wrappingType: Any.Type) {
    guard T.self is Unboxable.Type else {
        if T.self == Unboxable.self || T.self == Boxing.self {
            preconditionFailure("\(wrappingType) does not conform to Unboxable because Unboxable does not conform to itself. You must use a concrete type to box or unbox.")
        } else {
            preconditionFailure("\(wrappingType) does not conform to Unboxable because \(T.self) does not conform to Unboxable.")
        }
    }
}

// FIXME: Uncomment when conditional conformance is available.
extension Optional : Boxable /* where Wrapped : Boxable */ {
    public func box(to boxer: Boxer) throws {
        assertTypeIsEncodable(Wrapped.self, in: type(of: self))

        var container = boxer.singleValueContainer()
        switch self {
        case .none: try container.boxNil()
        case .some(let wrapped): try (wrapped as! Boxable).box(to: boxer)
        }
    }
}

extension Optional : Unboxable /* where Wrapped : Unboxable */ {
    public init(from unboxer: Unboxer) throws {
        // Initialize self here so we can get type(of: self).
        self = .none
        assertTypeIsDecodable(Wrapped.self, in: type(of: self))

        let container = try unboxer.singleValueContainer()
        if !container.unboxNil() {
            let metaType = (Wrapped.self as! Unboxable.Type)
            let element = try metaType.init(from: unboxer)
            self = .some(element as! Wrapped)
        }
    }
}

// FIXME: Uncomment when conditional conformance is available.
extension Array : Boxable /* where Element : Boxable */ {
    public func box(to boxer: Boxer) throws {
        assertTypeIsEncodable(Element.self, in: type(of: self))

        var container = boxer.unkeyedContainer()
        for element in self {
            // superBoxer appends an empty element and wraps an Boxer around it.
            // This is normally appropriate for encoding super, but this is really what we want to do.
            let subboxer = container.superBoxer()
            try (element as! Boxable).box(to: subboxer)
        }
    }
}

extension Array : Unboxable /* where Element : Unboxable */ {
    public init(from unboxer: Unboxer) throws {
        // Initialize self here so we can get type(of: self).
        self.init()
        assertTypeIsDecodable(Element.self, in: type(of: self))

        let metaType = (Element.self as! Unboxable.Type)
        var container = try unboxer.unkeyedContainer()
        while !container.isAtEnd {
            // superUnboxer fetches the next element as a container and wraps a Unboxer around it.
            // This is normally appropriate for decoding super, but this is really what we want to do.
            let subunboxer = try container.superUnboxer()
            let element = try metaType.init(from: subunboxer)
            self.append(element as! Element)
        }
    }
}

extension Set : Boxable /* where Element : Boxable */ {
    public func box(to boxer: Boxer) throws {
        assertTypeIsEncodable(Element.self, in: type(of: self))

        var container = boxer.unkeyedContainer()
        for element in self {
            // superBoxer appends an empty element and wraps an Boxer around it.
            // This is normally appropriate for encoding super, but this is really what we want to do.
            let subboxer = container.superBoxer()
            try (element as! Boxable).box(to: subboxer)
        }
    }
}

extension Set : Unboxable /* where Element : Unboxable */ {
    public init(from unboxer: Unboxer) throws {
        // Initialize self here so we can get type(of: self).
        self.init()
        assertTypeIsDecodable(Element.self, in: type(of: self))

        let metaType = (Element.self as! Unboxable.Type)
        var container = try unboxer.unkeyedContainer()
        while !container.isAtEnd {
            // superUnboxer fetches the next element as a container and wraps a Unboxer around it.
            // This is normally appropriate for decoding super, but this is really what we want to do.
            let subunboxer = try container.superUnboxer()
            let element = try metaType.init(from: subunboxer)
            self.insert(element as! Element)
        }
    }
}

/// A wrapper for dictionary keys which are Strings or Ints.
internal struct _DictionaryCodingKey : BoxingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

extension Dictionary : Boxable /* where Key : Boxable, Value : Boxable */ {
    public func box(to boxer: Boxer) throws {
        assertTypeIsEncodable(Key.self, in: type(of: self))
        assertTypeIsEncodable(Value.self, in: type(of: self))

        if Key.self == String.self {
            // Since the keys are already Strings, we can use them as keys directly.
            var container = boxer.container(keyedBy: _DictionaryCodingKey.self)
            for (key, value) in self {
                let codingKey = _DictionaryCodingKey(stringValue: key as! String)!
                let valueBoxer = container.superBoxer(forKey: codingKey)
                try (value as! Boxable).box(to: valueBoxer)
            }
        } else if Key.self == Int.self {
            // Since the keys are already Ints, we can use them as keys directly.
            var container = boxer.container(keyedBy: _DictionaryCodingKey.self)
            for (key, value) in self {
                let codingKey = _DictionaryCodingKey(intValue: key as! Int)!
                let valueBoxer = container.superBoxer(forKey: codingKey)
                try (value as! Boxable).box(to: valueBoxer)
            }
        } else {
            // Keys are Boxable but not Strings or Ints, so we cannot arbitrarily convert to keys.
            // We can box as an array of alternating key-value pairs, though.
            var container = boxer.unkeyedContainer()
            for (key, value) in self {
                // superBoxer appends an empty element and wraps an Boxer around it.
                // This is normally appropriate for encoding super, but this is really what we want to do.
                let keyBoxer = container.superBoxer()
                try (key as! Boxable).box(to: keyBoxer)

                let valueBoxer = container.superBoxer()
                try (value as! Boxable).box(to: valueBoxer)
            }
        }
    }
}

extension Dictionary : Unboxable /* where Key : Unboxable, Value : Unboxable */ {
    public init(from unboxer: Unboxer) throws {
        // Initialize self here so we can print type(of: self).
        self.init()
        assertTypeIsDecodable(Key.self, in: type(of: self))
        assertTypeIsDecodable(Value.self, in: type(of: self))

        if Key.self == String.self {
            // The keys are Strings, so we should be able to expect a keyed container.
            let container = try unboxer.container(keyedBy: _DictionaryCodingKey.self)
            let valueMetaType = Value.self as! Unboxable.Type
            for key in container.allKeys {
                let valueUnboxer = try container.superUnboxer(forKey: key)
                let value = try valueMetaType.init(from: valueUnboxer)
                self[key.stringValue as! Key] = (value as! Value)
            }
        } else if Key.self == Int.self {
            // The keys are Ints, so we should be able to expect a keyed container.
            let valueMetaType = Value.self as! Unboxable.Type
            let container = try unboxer.container(keyedBy: _DictionaryCodingKey.self)
            for key in container.allKeys {
                guard key.intValue != nil else {
                    // We provide stringValues for Int keys; if an boxer chooses not to use the actual intValues, we've boxd string keys.
                    // So on init, _DictionaryCodingKey tries to parse string keys as Ints. If that succeeds, then we would have had an intValue here.
                    // We don't, so this isn't a valid Int key.
                    var boxingPath = unboxer.boxingPath
                    boxingPath.append(key)
                    throw UnboxError.typeMismatch(Int.self,
                                                     UnboxError.Context(boxingPath: boxingPath,
                                                                           debugDescription: "Expected Int key but found String key instead."))
                }

                let valueUnboxer = try container.superUnboxer(forKey: key)
                let value = try valueMetaType.init(from: valueUnboxer)
                self[key.intValue! as! Key] = (value as! Value)
            }
        } else {
            // We should have boxd as an array of alternating key-value pairs.
            var container = try unboxer.unkeyedContainer()

            // We're expecting to get pairs. If the container has a known count, it had better be even; no point in doing work if not.
            if let count = container.count {
                guard count % 2 == 0 else {
                    throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath,
                                                                            debugDescription: "Expected collection of key-value pairs; encountered odd-length array instead."))
                }
            }

            let keyMetaType = (Key.self as! Unboxable.Type)
            let valueMetaType = (Value.self as! Unboxable.Type)
            while !container.isAtEnd {
                // superUnboxer fetches the next element as a container and wraps a Unboxer around it.
                // This is normally appropriate for decoding super, but this is really what we want to do.
                let keyUnboxer = try container.superUnboxer()
                let key = try keyMetaType.init(from: keyUnboxer)

                guard !container.isAtEnd else {
                    throw UnboxError.dataCorrupted(UnboxError.Context(boxingPath: unboxer.boxingPath,
                                                                            debugDescription: "Unkeyed container reached end before value in key-value pair."))
                }

                let valueUnboxer = try container.superUnboxer()
                let value = try valueMetaType.init(from: valueUnboxer)

                self[key as! Key] = (value as! Value)
            }
        }
    }
}

//===----------------------------------------------------------------------===//
// Convenience Default Implementations
//===----------------------------------------------------------------------===//

// Default implementation of boxConditional(_:forKey:) in terms of box(_:forKey:)
public extension KeyedBoxingContainerProtocol {
    public mutating func boxConditional<T : AnyObject & Boxable>(_ object: T, forKey key: Key) throws {
        try box(object, forKey: key)
    }
}

// Default implementation of boxIfPresent(_:forKey:) in terms of box(_:forKey:)
public extension KeyedBoxingContainerProtocol {
    public mutating func boxIfPresent(_ value: Bool?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: Int?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: Int8?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: Int16?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: Int32?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: Int64?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: UInt?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: UInt8?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: UInt16?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: UInt32?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: UInt64?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: Float?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: Double?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent(_ value: String?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }

    public mutating func boxIfPresent<T : Boxable>(_ value: T?, forKey key: Key) throws {
        guard let value = value else { return }
        try box(value, forKey: key)
    }
}

// Default implementation of unboxIfPresent(_:forKey:) in terms of unbox(_:forKey:) and unboxNil(forKey:)
public extension KeyedUnboxingContainerProtocol {
    public func unboxIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(Bool.self, forKey: key)
    }

    public func unboxIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(Int.self, forKey: key)
    }

    public func unboxIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(Int8.self, forKey: key)
    }

    public func unboxIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(Int16.self, forKey: key)
    }

    public func unboxIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(Int32.self, forKey: key)
    }

    public func unboxIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(Int64.self, forKey: key)
    }

    public func unboxIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(UInt.self, forKey: key)
    }

    public func unboxIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(UInt8.self, forKey: key)
    }

    public func unboxIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(UInt16.self, forKey: key)
    }

    public func unboxIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(UInt32.self, forKey: key)
    }

    public func unboxIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(UInt64.self, forKey: key)
    }

    public func unboxIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(Float.self, forKey: key)
    }

    public func unboxIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(Double.self, forKey: key)
    }

    public func unboxIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(String.self, forKey: key)
    }

    public func unboxIfPresent<T : Unboxable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard try self.contains(key) && !self.unboxNil(forKey: key) else { return nil }
        return try self.unbox(T.self, forKey: key)
    }
}

// Default implementation of boxConditional(_:) in terms of box(_:), and box(contentsOf:) in terms of box(_:) loop.
public extension UnkeyedBoxingContainer {
    public mutating func boxConditional<T : AnyObject & Boxable>(_ object: T) throws {
        try self.box(object)
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Bool {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int8 {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int16 {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int32 {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Int64 {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt8 {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt16 {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt32 {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == UInt64 {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Float {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == Double {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element == String {
        for element in sequence {
            try self.box(element)
        }
    }

    public mutating func box<T : Sequence>(contentsOf sequence: T) throws where T.Iterator.Element : Boxable {
        for element in sequence {
            try self.box(element)
        }
    }
}

// Default implementation of unboxIfPresent(_:) in terms of unbox(_:) and unboxNil()
public extension UnkeyedUnboxingContainer {
    mutating func unboxIfPresent(_ type: Bool.Type) throws -> Bool? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(Bool.self)
    }

    mutating func unboxIfPresent(_ type: Int.Type) throws -> Int? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(Int.self)
    }

    mutating func unboxIfPresent(_ type: Int8.Type) throws -> Int8? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(Int8.self)
    }
    
    mutating func unboxIfPresent(_ type: Int16.Type) throws -> Int16? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(Int16.self)
    }
    
    mutating func unboxIfPresent(_ type: Int32.Type) throws -> Int32? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(Int32.self)
    }
    
    mutating func unboxIfPresent(_ type: Int64.Type) throws -> Int64? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(Int64.self)
    }
    
    mutating func unboxIfPresent(_ type: UInt.Type) throws -> UInt? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(UInt.self)
    }
    
    mutating func unboxIfPresent(_ type: UInt8.Type) throws -> UInt8? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(UInt8.self)
    }
    
    mutating func unboxIfPresent(_ type: UInt16.Type) throws -> UInt16? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(UInt16.self)
    }
    
    mutating func unboxIfPresent(_ type: UInt32.Type) throws -> UInt32? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(UInt32.self)
    }
    
    mutating func unboxIfPresent(_ type: UInt64.Type) throws -> UInt64? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(UInt64.self)
    }
    
    mutating func unboxIfPresent(_ type: Float.Type) throws -> Float? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(Float.self)
    }
    
    mutating func unboxIfPresent(_ type: Double.Type) throws -> Double? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(Double.self)
    }
    
    mutating func unboxIfPresent(_ type: String.Type) throws -> String? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(String.self)
    }
    
    mutating func unboxIfPresent<T : Unboxable>(_ type: T.Type) throws -> T? {
        guard try !self.isAtEnd && !self.unboxNil() else { return nil }
        return try self.unbox(T.self)
    }
}
