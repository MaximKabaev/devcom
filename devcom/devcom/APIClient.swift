import Foundation

nonisolated enum APIError: LocalizedError {
    case invalidServerURL
    case invalidResponse
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL: "Enter a valid HTTPS server URL."
        case .invalidResponse: "The server returned an unreadable response."
        case .unauthorized: "Your session is no longer valid. Sign in again."
        case .server(let message): message
        }
    }
}

actor APIClient {
    private let baseURL: URL
    private let token: String?
    private let session: URLSession

    init(baseURL: URL, token: String? = nil) {
        self.baseURL = baseURL
        self.token = token
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        try await request(path: "/v1/auth/login", method: "POST", body: ["username": username, "password": password])
    }

    func events() async throws -> EventsResponse { try await request(path: "/v1/events") }

    func createAction(name: String, method: String, url: String, headers: [String: String], body: String?) async throws -> ActionEvent {
        struct Payload: Encodable {
            let name: String
            let method: String
            let url: String
            let headers: [String: String]
            let body: String?
        }
        return try await request(
            path: "/v1/actions",
            method: "POST",
            body: Payload(name: name, method: method, url: url, headers: headers, body: body)
        )
    }

    func createListen(name: String) async throws -> ListenEvent {
        try await request(path: "/v1/listens", method: "POST", body: ["name": name])
    }

    func runAction(id: String) async throws -> ActionRunResult {
        try await request(path: "/v1/actions/\(id)/run", method: "POST")
    }

    func deleteAction(id: String) async throws {
        try await requestWithoutResponse(path: "/v1/actions/\(id)", method: "DELETE")
    }

    func deleteListen(id: String) async throws {
        try await requestWithoutResponse(path: "/v1/listens/\(id)", method: "DELETE")
    }

    func registerDevice(token deviceToken: String) async throws {
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        try await requestWithoutResponse(
            path: "/v1/devices",
            method: "POST",
            body: ["token": deviceToken, "environment": environment]
        )
    }

    private func request<Response: Decodable>(path: String, method: String = "GET", body: (any Encodable)? = nil) async throws -> Response {
        let (data, _) = try await perform(path: path, method: method, body: body)
        do { return try JSONDecoder().decode(Response.self, from: data) }
        catch { throw APIError.invalidResponse }
    }

    private func requestWithoutResponse(path: String, method: String, body: (any Encodable)? = nil) async throws {
        _ = try await perform(path: path, method: method, body: body)
    }

    private func perform(path: String, method: String, body: (any Encodable)?) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidServerURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ServerError.self, from: data).error)
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.server(message)
        }
        return (data, http)
    }
}

private nonisolated struct ServerError: Decodable { let error: String }

private nonisolated struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void
    init(_ value: any Encodable) { encodeValue = value.encode }
    func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
}
