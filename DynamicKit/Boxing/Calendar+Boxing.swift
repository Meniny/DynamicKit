//
//  Calendar+Boxing.swift
//  Boxing


import Foundation

extension Calendar : Boxing {

    internal static func _toNSCalendarIdentifier(_ identifier : Identifier) -> NSCalendar.Identifier {
        if #available(OSX 10.10, iOS 8.0, *) {
            let identifierMap : [Identifier : NSCalendar.Identifier] =
                [.gregorian : .gregorian,
                 .buddhist : .buddhist,
                 .chinese : .chinese,
                 .coptic : .coptic,
                 .ethiopicAmeteMihret : .ethiopicAmeteMihret,
                 .ethiopicAmeteAlem : .ethiopicAmeteAlem,
                 .hebrew : .hebrew,
                 .iso8601 : .ISO8601,
                 .indian : .indian,
                 .islamic : .islamic,
                 .islamicCivil : .islamicCivil,
                 .japanese : .japanese,
                 .persian : .persian,
                 .republicOfChina : .republicOfChina,
                 .islamicTabular : .islamicTabular,
                 .islamicUmmAlQura : .islamicUmmAlQura]
            return identifierMap[identifier]!
        } else {
            let identifierMap : [Identifier : NSCalendar.Identifier] =
                [.gregorian : .gregorian,
                 .buddhist : .buddhist,
                 .chinese : .chinese,
                 .coptic : .coptic,
                 .ethiopicAmeteMihret : .ethiopicAmeteMihret,
                 .ethiopicAmeteAlem : .ethiopicAmeteAlem,
                 .hebrew : .hebrew,
                 .iso8601 : .ISO8601,
                 .indian : .indian,
                 .islamic : .islamic,
                 .islamicCivil : .islamicCivil,
                 .japanese : .japanese,
                 .persian : .persian,
                 .republicOfChina : .republicOfChina]
            return identifierMap[identifier]!
        }
    }

    internal static func _fromNSCalendarIdentifier(_ identifier : NSCalendar.Identifier) -> Identifier {
        if #available(OSX 10.10, iOS 8.0, *) {
            let identifierMap : [NSCalendar.Identifier : Identifier] =
                [.gregorian : .gregorian,
                 .buddhist : .buddhist,
                 .chinese : .chinese,
                 .coptic : .coptic,
                 .ethiopicAmeteMihret : .ethiopicAmeteMihret,
                 .ethiopicAmeteAlem : .ethiopicAmeteAlem,
                 .hebrew : .hebrew,
                 .ISO8601 : .iso8601,
                 .indian : .indian,
                 .islamic : .islamic,
                 .islamicCivil : .islamicCivil,
                 .japanese : .japanese,
                 .persian : .persian,
                 .republicOfChina : .republicOfChina,
                 .islamicTabular : .islamicTabular,
                 .islamicUmmAlQura : .islamicUmmAlQura]
            return identifierMap[identifier]!
        } else {
            let identifierMap : [NSCalendar.Identifier : Identifier] =
                [.gregorian : .gregorian,
                 .buddhist : .buddhist,
                 .chinese : .chinese,
                 .coptic : .coptic,
                 .ethiopicAmeteMihret : .ethiopicAmeteMihret,
                 .ethiopicAmeteAlem : .ethiopicAmeteAlem,
                 .hebrew : .hebrew,
                 .ISO8601 : .iso8601,
                 .indian : .indian,
                 .islamic : .islamic,
                 .islamicCivil : .islamicCivil,
                 .japanese : .japanese,
                 .persian : .persian,
                 .republicOfChina : .republicOfChina]
            return identifierMap[identifier]!
        }
    }

    private enum CodingKeys : Int, BoxingKey {
        case identifier
        case locale
        case timeZone
        case firstWeekday
        case minimumDaysInFirstWeek
    }

    public init(from unboxer: Unboxer) throws {
        let container = try unboxer.container(keyedBy: CodingKeys.self)
        let identifierString = try container.unbox(String.self, forKey: .identifier)
        let identifier = Calendar._fromNSCalendarIdentifier(NSCalendar.Identifier(rawValue: identifierString))
        self.init(identifier: identifier)

        self.locale = try container.unboxIfPresent(Locale.self, forKey: .locale)
        self.timeZone = try container.unbox(TimeZone.self, forKey: .timeZone)
        self.firstWeekday = try container.unbox(Int.self, forKey: .firstWeekday)
        self.minimumDaysInFirstWeek = try container.unbox(Int.self, forKey: .minimumDaysInFirstWeek)
    }

    public func box(to boxer: Boxer) throws {
        var container = boxer.container(keyedBy: CodingKeys.self)

        let identifier = Calendar._toNSCalendarIdentifier(self.identifier).rawValue
        try container.box(identifier, forKey: .identifier)
        try container.box(self.locale, forKey: .locale)
        try container.box(self.timeZone, forKey: .timeZone)
        try container.box(self.firstWeekday, forKey: .firstWeekday)
        try container.box(self.minimumDaysInFirstWeek, forKey: .minimumDaysInFirstWeek)
    }
}
