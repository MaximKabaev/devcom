import Foundation
import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class AppModel {
    private(set) var isAuthenticated = false
    private(set) var actions: [ActionEvent] = []
    private(set) var listeners: [Listener] = []
    private(set) var projects: [Project] = []
    private(set) var isRestoringSession = true
    private(set) var isLoading = false
    private(set) var runningActionID: String?
    var errorMessage: String?
    var runResult: ActionRunResult?

    private var client: APIClient?
    private var didRestore = false

    func restoreSession() async {
        guard !didRestore else { return }
        didRestore = true
        defer { isRestoringSession = false }
        guard let stored = KeychainStore.load(), let url = Self.normalizedServerURL(stored.serverURL) else { return }
        client = APIClient(baseURL: url, token: stored.token)
        isAuthenticated = true
        await refresh()
        isRestoringSession = false
        await requestNotificationsAndRegister()
    }

    func login(server: String, username: String, password: String) async -> Bool {
        guard let url = Self.normalizedServerURL(server) else {
            errorMessage = APIError.invalidServerURL.localizedDescription
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await APIClient(baseURL: url).login(username: username, password: password)
            let stored = StoredSession(serverURL: url.absoluteString, token: response.token)
            try KeychainStore.save(stored)
            client = APIClient(baseURL: url, token: response.token)
            isAuthenticated = true
            errorMessage = nil
            await refresh()
            await requestNotificationsAndRegister()
            return true
        } catch APIError.unauthorized {
            errorMessage = "Invalid username or password."
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func logout() {
        KeychainStore.clear()
        client = nil
        actions = []
        listeners = []
        projects = []
        isAuthenticated = false
    }

    func refresh() async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await client.events()
            actions = response.actions
            listeners = response.listeners
            projects = response.projects
            errorMessage = nil
        } catch APIError.unauthorized {
            logout()
            errorMessage = APIError.unauthorized.localizedDescription
        } catch { errorMessage = error.localizedDescription }
    }

    func createAction(name: String, method: String, url: String, headers: [String: String], body: String?, projectId: String?, schedule: ActionSchedulePayload?) async -> Bool {
        guard let client else { return false }
        do {
            let event = try await client.createAction(name: name, method: method, url: url, headers: headers, body: body, projectId: projectId, schedule: schedule)
            actions.append(event)
            errorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func createListener(name: String, projectId: String?) async -> Bool {
        guard let client else { return false }
        do {
            listeners.append(try await client.createListener(name: name, projectId: projectId))
            errorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func updateAction(
        _ action: ActionEvent,
        name: String,
        method: String,
        url: String,
        headers: [String: String],
        body: String?,
        projectId: String?,
        schedule: ActionSchedulePayload?
    ) async -> Bool {
        guard let client else { return false }
        do {
            let updated = try await client.updateAction(
                id: action.id,
                name: name,
                method: method,
                url: url,
                headers: headers,
                body: body,
                projectId: projectId,
                schedule: schedule
            )
            if let index = actions.firstIndex(where: { $0.id == updated.id }) { actions[index] = updated }
            errorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func updateListener(_ listener: Listener, name: String, projectId: String?) async -> Bool {
        guard let client else { return false }
        do {
            let updated = try await client.updateListener(id: listener.id, name: name, projectId: projectId)
            if let index = listeners.firstIndex(where: { $0.id == updated.id }) { listeners[index] = updated }
            errorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func createProject(name: String, color: ProjectColor) async -> Bool {
        guard let client else { return false }
        do {
            projects.append(try await client.createProject(name: name, color: color))
            errorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func updateProject(_ project: Project, name: String, color: ProjectColor) async -> Bool {
        guard let client else { return false }
        do {
            let updated = try await client.updateProject(id: project.id, name: name, color: color)
            if let index = projects.firstIndex(where: { $0.id == updated.id }) { projects[index] = updated }
            errorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func deleteProject(_ project: Project) async {
        guard let client else { return }
        do {
            try await client.deleteProject(id: project.id)
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func run(_ action: ActionEvent) async {
        guard let client else { return }
        runningActionID = action.id
        defer { runningActionID = nil }
        do { runResult = try await client.runAction(id: action.id); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    func deleteAction(_ action: ActionEvent) async {
        guard let client else { return }
        do { try await client.deleteAction(id: action.id); actions.removeAll { $0.id == action.id } }
        catch { errorMessage = error.localizedDescription }
    }

    func deleteListener(_ listener: Listener) async {
        guard let client else { return }
        do { try await client.deleteListener(id: listener.id); listeners.removeAll { $0.id == listener.id } }
        catch { errorMessage = error.localizedDescription }
    }

    func registerDevice(token: String) async {
        guard let client else { return }
        do { try await client.registerDevice(token: token) }
        catch { errorMessage = error.localizedDescription }
    }

    private func requestNotificationsAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            if let token = UserDefaults.standard.string(forKey: "pushDeviceToken") { await registerDevice(token: token) }
        } catch { errorMessage = "Notification permission could not be requested." }
    }

    private static func normalizedServerURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed), components.scheme == "https", components.host != nil else { return nil }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
