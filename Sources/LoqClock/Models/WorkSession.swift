import Foundation

struct WorkSession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var assignedWorkDayDate: LocalDay
    var startTimestamp: Date
    var endTimestamp: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        assignedWorkDayDate: LocalDay,
        startTimestamp: Date,
        endTimestamp: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.assignedWorkDayDate = assignedWorkDayDate
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func touch(_ timestamp: Date = .now) {
        updatedAt = timestamp
    }
}
