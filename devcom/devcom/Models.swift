import Foundation

nonisolated struct ActionEvent: Codable, Identifiable, Sendable {
    let id: String
    let kind: String
    let name: String
    let method: String
    let url: String
    let headers: [String: String]
    let body: String?
    let createdAt: String
    let updatedAt: String
}

nonisolated struct Listener: Codable, Identifiable, Sendable {
    let id: String
    let kind: String
    let name: String
    let webhookURL: String
    let createdAt: String
    let updatedAt: String
}

nonisolated struct EventsResponse: Codable, Sendable {
    let actions: [ActionEvent]
    let listeners: [Listener]
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
