//
//  PersonNameComponents+Boxing.swift
//  Boxing


import Foundation

@available(OSX 10.11, iOS 9.0, *)
extension PersonNameComponents : Boxing {
    private enum CodingKeys : Int, BoxingKey {
        case namePrefix
        case givenName
        case middleName
        case familyName
        case nameSuffix
        case nickname
    }

    public init(from unboxer: Unboxer) throws {
        self.init()

        let container = try unboxer.container(keyedBy: CodingKeys.self)
        self.namePrefix = try container.unboxIfPresent(String.self, forKey: .namePrefix)
        self.givenName  = try container.unboxIfPresent(String.self, forKey: .givenName)
        self.middleName = try container.unboxIfPresent(String.self, forKey: .middleName)
        self.familyName = try container.unboxIfPresent(String.self, forKey: .familyName)
        self.nameSuffix = try container.unboxIfPresent(String.self, forKey: .nameSuffix)
        self.nickname   = try container.unboxIfPresent(String.self, forKey: .nickname)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.container(keyedBy: CodingKeys.self)
        if let np = self.namePrefix { try container.box(np, forKey: .namePrefix) }
        if let gn = self.givenName  { try container.box(gn, forKey: .givenName) }
        if let mn = self.middleName { try container.box(mn, forKey: .middleName) }
        if let fn = self.familyName { try container.box(fn, forKey: .familyName) }
        if let ns = self.nameSuffix { try container.box(ns, forKey: .nameSuffix) }
        if let nn = self.nickname   { try container.box(nn, forKey: .nickname) }
    }
}
