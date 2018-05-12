//
//  DateComponents+Boxing.swift
//  Boxing


import Foundation

extension DateComponents : Boxing {
    private enum CodingKeys : Int, BoxingKey {
        case calendar
        case timeZone
        case era
        case year
        case month
        case day
        case hour
        case minute
        case second
        case nanosecond
        case weekday
        case weekdayOrdinal
        case quarter
        case weekOfMonth
        case weekOfYear
        case yearForWeekOfYear
    }

    public init(from unboxer: Unboxer) throws {
        let container  = try unboxer.container(keyedBy: CodingKeys.self)
        let calendar   = try container.unboxIfPresent(Calendar.self, forKey: .calendar)
        let timeZone   = try container.unboxIfPresent(TimeZone.self, forKey: .timeZone)
        let era        = try container.unboxIfPresent(Int.self, forKey: .era)
        let year       = try container.unboxIfPresent(Int.self, forKey: .year)
        let month      = try container.unboxIfPresent(Int.self, forKey: .month)
        let day        = try container.unboxIfPresent(Int.self, forKey: .day)
        let hour       = try container.unboxIfPresent(Int.self, forKey: .hour)
        let minute     = try container.unboxIfPresent(Int.self, forKey: .minute)
        let second     = try container.unboxIfPresent(Int.self, forKey: .second)
        let nanosecond = try container.unboxIfPresent(Int.self, forKey: .nanosecond)

        let weekday           = try container.unboxIfPresent(Int.self, forKey: .weekday)
        let weekdayOrdinal    = try container.unboxIfPresent(Int.self, forKey: .weekdayOrdinal)
        let quarter           = try container.unboxIfPresent(Int.self, forKey: .quarter)
        let weekOfMonth       = try container.unboxIfPresent(Int.self, forKey: .weekOfMonth)
        let weekOfYear        = try container.unboxIfPresent(Int.self, forKey: .weekOfYear)
        let yearForWeekOfYear = try container.unboxIfPresent(Int.self, forKey: .yearForWeekOfYear)

        self.init(calendar: calendar,
                  timeZone: timeZone,
                  era: era,
                  year: year,
                  month: month,
                  day: day,
                  hour: hour,
                  minute: minute,
                  second: second,
                  nanosecond: nanosecond,
                  weekday: weekday,
                  weekdayOrdinal: weekdayOrdinal,
                  quarter: quarter,
                  weekOfMonth: weekOfMonth,
                  weekOfYear: weekOfYear,
                  yearForWeekOfYear: yearForWeekOfYear)
    }

    public func box(to boxer: Boxer) throws {
        // TODO: Replace all with boxIfPresent, when added.
        var container = boxer.container(keyedBy: CodingKeys.self)
        if self.calendar   != nil { try container.box(self.calendar!, forKey: .calendar) }
        if self.timeZone   != nil { try container.box(self.timeZone!, forKey: .timeZone) }
        if self.era        != nil { try container.box(self.era!, forKey: .era) }
        if self.year       != nil { try container.box(self.year!, forKey: .year) }
        if self.month      != nil { try container.box(self.month!, forKey: .month) }
        if self.day        != nil { try container.box(self.day!, forKey: .day) }
        if self.hour       != nil { try container.box(self.hour!, forKey: .hour) }
        if self.minute     != nil { try container.box(self.minute!, forKey: .minute) }
        if self.second     != nil { try container.box(self.second!, forKey: .second) }
        if self.nanosecond != nil { try container.box(self.nanosecond!, forKey: .nanosecond) }

        if self.weekday           != nil { try container.box(self.weekday!, forKey: .weekday) }
        if self.weekdayOrdinal    != nil { try container.box(self.weekdayOrdinal!, forKey: .weekdayOrdinal) }
        if self.quarter           != nil { try container.box(self.quarter!, forKey: .quarter) }
        if self.weekOfMonth       != nil { try container.box(self.weekOfMonth!, forKey: .weekOfMonth) }
        if self.weekOfYear        != nil { try container.box(self.weekOfYear!, forKey: .weekOfYear) }
        if self.yearForWeekOfYear != nil { try container.box(self.yearForWeekOfYear!, forKey: .yearForWeekOfYear) }
    }
}
