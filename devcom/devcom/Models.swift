import Foundation

nonisolated enum ScheduleFrequency: String, Codable, Sendable {
    case once, weekly
}

nonisolated struct ActionSchedule: Codable, Sendable {
    let frequency: ScheduleFrequency
    let enabled: Bool
    let runAt: String?
    let weekdays: [Int]
    let timeOfDay: String?
    let timeZone: String
    let nextRunAt: String?
    let lastRunAt: String?
    let lastRunStatus: String?
    let lastError: String?
}

nonisolated enum ActionSchedulePayload: Encodable, Sendable {
    case once(runAt: String, timeZone: String)
    case weekly(weekdays: [Int], timeOfDay: String, timeZone: String)

    private enum CodingKeys: String, CodingKey { case frequency, enabled, runAt, weekdays, timeOfDay, timeZone }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(true, forKey: .enabled)
        switch self {
        case .once(let runAt, let timeZone):
            try container.encode(ScheduleFrequency.once.rawValue, forKey: .frequency)
            try container.encode(runAt, forKey: .runAt)
            try container.encode(timeZone, forKey: .timeZone)
        case .weekly(let weekdays, let timeOfDay, let timeZone):
            try container.encode(ScheduleFrequency.weekly.rawValue, forKey: .frequency)
            try container.encode(weekdays, forKey: .weekdays)
            try container.encode(timeOfDay, forKey: .timeOfDay)
            try container.encode(timeZone, forKey: .timeZone)
        }
    }
}

nonisolated struct ActionEvent: Codable, Identifiable, Sendable {
    let id: String
    let kind: String
    let name: String
    let method: String
    let url: String
    let headers: [String: String]
    let body: String?
    let projectId: String?
    let schedule: ActionSchedule?
    let createdAt: String
    let updatedAt: String
}

nonisolated struct Listener: Codable, Identifiable, Sendable {
    let id: String
    let kind: String
    let name: String
    let webhookURL: String
    let projectId: String?
    let createdAt: String
    let updatedAt: String
}

nonisolated enum ProjectColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue, violet, mint, amber, rose, slate
    var id: String { rawValue }
}

nonisolated struct Project: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let color: ProjectColor
    let createdAt: String
    let updatedAt: String
}

nonisolated struct EventsResponse: Codable, Sendable {
    let actions: [ActionEvent]
    let listeners: [Listener]
    let projects: [Project]
}

nonisolated struct LoginResponse: Codable, Sendable { let token: String }

nonisolated struct ActionRunResult: Codable, Identifiable, Sendable {
    let ok: Bool
    let status: Int
    let durationMs: Int
    let response: String
    let truncated: Bool

    var id: String { "\(status)-\(durationMs)-\(response)" }
}

nonisolated struct StoredSession: Codable, Sendable {
    let serverURL: String
    let token: String
}

enum EventSection: String, CaseIterable, Identifiable {
    case actions = "Actions"
    case listeners = "Listeners"
    var id: String { rawValue }
}
