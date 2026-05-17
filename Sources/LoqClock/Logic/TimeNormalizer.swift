import Foundation

enum TimeNormalizer {
    static func roundedDownToMinute(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: floor(date.timeIntervalSinceReferenceDate / 60) * 60)
    }

    static func roundedUpToMinuteIfNeeded(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: ceil(date.timeIntervalSinceReferenceDate / 60) * 60)
    }
}
