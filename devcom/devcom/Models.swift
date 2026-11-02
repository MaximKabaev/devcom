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

nonisolated enum ScheduleItemPayload: Encodable, Sendable {
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

nonisolated struct ActionSchedules: Codable, Sendable {
    let once: ActionSchedule?
    let recurring: ActionSchedule?
}

nonisolated struct ActionSchedulePayload: Encodable, Sendable {
    let once: ScheduleItemPayload?
    let recurring: ScheduleItemPayload?
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
    let schedule: ActionSchedules
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

/// Who made a call, as recorded by the server. `client` is the label the iOS
/// app sends about itself; `userAgent` is whatever any other client announced.
nonisolated struct HistoryCaller: Codable, Sendable {
    let channel: String?
    let ip: String?
    let userAgent: String?
    let client: String?
}

/// Coarse origin used for filtering the log.
nonisolated enum LogOrigin: Sendable {
    case app, external, scheduled, unknown
}

/// Delivery counts the server stores as JSON in a notification's `response`.
nonisolated struct DeliveryReport: Decodable, Sendable {
    let delivered: Int?
    let failed: Int?
    let devices: Int?
    let errors: [Failure]?

    nonisolated struct Failure: Decodable, Sendable {
        let reason: String
        let count: Int
    }
}

/// A server-side record of an action execution or an inbound listener delivery.
/// Optional fields keep the client compatible with older history records and
/// with the two different event shapes returned by the API.
nonisolated struct HistoryEntry: Codable, Identifiable, Sendable {
    let id: String
    let kind: String?
    let eventId: String?
    let eventName: String?
    let actionId: String?
    let listenerId: String?
    let source: String?
    let status: String?
    let statusCode: Int?
    let method: String?
    let url: String?
    let occurredAt: String?
    let createdAt: String?
    let durationMs: Int?
    let response: String?
    let error: String?
    let projectId: String?
    let title: String?
    let message: String?
    let caller: HistoryCaller?

    var displayKind: String {
        switch (kind ?? "").lowercased() {
        case "listener", "listen", "inbound": return "Listener"
        default: return "Action"
        }
    }

    var isNotification: Bool { displayKind == "Listener" }
    var displayName: String { eventName ?? eventId ?? actionId ?? listenerId ?? "Unknown event" }
    var timestamp: String? { occurredAt ?? createdAt }

    var date: Date {
        guard let value = timestamp else { return .distantPast }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractional.date(from: value) { return parsed }
        return ISO8601DateFormatter().date(from: value) ?? .distantPast
    }

    var isFailure: Bool { status?.lowercased() == "failed" }
    var isSuccess: Bool { ["succeeded", "accepted"].contains(status?.lowercased() ?? "") }

    /// The channel the server recorded, or for older entries the coarse
    /// `source`, which cannot tell the app apart from another API client.
    private var originKey: String { (caller?.channel ?? source ?? "").lowercased() }

    var origin: LogOrigin {
        switch originKey {
        case "app": .app
        case "api", "webhook", "agent": .external
        case "scheduler", "scheduled": .scheduled
        default: .unknown
        }
    }

    var originTitle: String {
        switch originKey {
        case "app": "App"
        case "api", "agent": "API"
        case "webhook": "Webhook"
        case "scheduler", "scheduled": "Schedule"
        case "manual": "Manual"
        default: "Unknown"
        }
    }

    var originSymbol: String {
        switch originKey {
        case "app": "iphone"
        case "api", "agent": "network"
        case "webhook": "link"
        case "scheduler", "scheduled": "clock"
        default: "questionmark.circle"
        }
    }

    /// True for entries recorded before the server kept caller details.
    var originIsPartial: Bool { caller == nil }

    var deliveryReport: DeliveryReport? {
        guard isNotification, let data = response?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DeliveryReport.self, from: data)
    }

    /// The response body, pretty-printed when it is a JSON object or array.
    var formattedResponse: String? {
        guard let response, !response.isEmpty else { return nil }
        if let data = response.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           object is [String: Any] || object is [Any],
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
           let text = String(data: pretty, encoding: .utf8) {
            return text
        }
        return response
    }

    /// Everything a search should be able to match.
    var searchText: String {
        [displayName, title, message, url, caller?.ip, caller?.client, caller?.userAgent, originTitle]
            .compactMap { $0 }.joined(separator: "\n")
    }
}

nonisolated struct HistoryResponse: Decodable, Sendable {
    let history: [HistoryEntry]

    init(from decoder: Decoder) throws {
        if let values = try? decoder.singleValueContainer().decode([HistoryEntry].self) {
            history = values
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        history = try container.decodeIfPresent([HistoryEntry].self, forKey: .history)
            ?? container.decodeIfPresent([HistoryEntry].self, forKey: .entries)
            ?? container.decodeIfPresent([HistoryEntry].self, forKey: .items)
            ?? []
    }

    private enum CodingKeys: String, CodingKey { case history, entries, items }
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
