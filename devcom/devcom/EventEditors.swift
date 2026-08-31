import SwiftUI

struct ActionEditorView: View {
    @Bindable var model: AppModel
    let action: ActionEvent?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var method: String
    @State private var url: String
    @State private var headers: String
    @State private var requestBody: String
    @State private var projectId: String?
    @State private var validationMessage: String?
    @State private var isSaving = false

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE"]

    init(model: AppModel, action: ActionEvent? = nil, initialProjectId: String? = nil) {
        self.model = model
        self.action = action
        _name = State(initialValue: action?.name ?? "")
        _method = State(initialValue: action?.method ?? "POST")
        _url = State(initialValue: action?.url ?? "")
        _headers = State(initialValue: Self.formattedHeaders(action?.headers))
        _requestBody = State(initialValue: action?.body ?? "")
        _projectId = State(initialValue: action?.projectId ?? initialProjectId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Action") {
                    TextField("Name", text: $name, prompt: Text("Restart media server"))
                    Picker("Method", selection: $method) {
                        ForEach(methods, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Endpoint", text: $url, prompt: Text("https://service.example.com/restart"))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }


                Section("Project") {
                    ProjectPickerRow(projects: model.projects, selection: $projectId)
                }

                Section {
                    TextEditor(text: $headers)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 104)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Headers · JSON")
                } footer: {
                    Text("Credentials are encrypted in the backend data file.")
                }

                if method != "GET" && method != "DELETE" {
                    Section("Request body") {
                        TextEditor(text: $requestBody)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(minHeight: 130)
                            .textInputAutocapitalization(.never)
                    }
                }

                if let validationMessage {
                    Section { Text(validationMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(action == nil ? "New action" : "Action configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || url.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        guard let data = headers.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            validationMessage = "Headers must be a JSON object whose keys and values are strings."
            return
        }
        guard let parsedURL = URL(string: url),
              let scheme = parsedURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            validationMessage = "Enter a complete HTTP or HTTPS endpoint."
            return
        }
        validationMessage = nil
        isSaving = true
        Task {
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let savedBody = method == "GET" || method == "DELETE" || requestBody.isEmpty ? nil : requestBody
            let saved: Bool
            if let action {
                saved = await model.updateAction(
                    action,
                    name: cleanName,
                    method: method,
                    url: url,
                    headers: object,
                    body: savedBody,
                    projectId: projectId
                )
            } else {
                saved = await model.createAction(
                    name: cleanName,
                    method: method,
                    url: url,
                    headers: object,
                    body: savedBody,
                    projectId: projectId
                )
            }
            isSaving = false
            if saved { dismiss() }
        }
    }

    private static func formattedHeaders(_ headers: [String: String]?) -> String {
        guard let headers else { return "{\n  \"Content-Type\": \"application/json\"\n}" }
        guard let data = try? JSONSerialization.data(withJSONObject: headers, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}

struct ListenerEditorView: View {
    @Bindable var model: AppModel
    let listener: Listener?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var projectId: String?
    @State private var isSaving = false

    init(model: AppModel, listener: Listener? = nil, initialProjectId: String? = nil) {
        self.model = model
        self.listener = listener
        _name = State(initialValue: listener?.name ?? "")
        _projectId = State(initialValue: listener?.projectId ?? initialProjectId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Deploy finished"))
                } footer: {
                    Text(listener == nil ? "After saving, copy the secret URL and POST a title and message to it." : "Renaming a listener does not change its secret webhook URL.")
                }


                Section("Project") {
                    ProjectPickerRow(projects: model.projects, selection: $projectId)
                }

                if let listener {
                    Section("Webhook URL") {
                        Text(listener.webhookURL)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                        Button {
                            UIPasteboard.general.string = listener.webhookURL
                        } label: {
                            Label("Copy webhook URL", systemImage: "link")
                        }
                    }
                }

                Section("Accepted payload") {
                    Text("{\n  \"title\": \"Deploy complete\",\n  \"message\": \"api.example.com is live\"\n}")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(DevcomTheme.muted)
                }
            }
            .navigationTitle(listener == nil ? "New listener" : "Listener configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        isSaving = true
                        Task {
                            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let saved: Bool
                            if let listener {
                                saved = await model.updateListener(listener, name: cleanName, projectId: projectId)
                            } else {
                                saved = await model.createListener(name: cleanName, projectId: projectId)
                            }
                            isSaving = false
                            if saved { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }
}

private struct ProjectPickerRow: View {
    let projects: [Project]
    @Binding var selection: String?

    private var selectedProject: Project? {
        guard let selection else { return nil }
        return projects.first { $0.id == selection }
    }

    var body: some View {
        HStack {
            Text("Group")
            Spacer()
            Menu {
                Button { selection = nil } label: {
                    Label("No project", systemImage: selection == nil ? "checkmark" : "minus")
                }
                ForEach(projects) { project in
                    Button { selection = project.id } label: {
                        Label(project.name, systemImage: selection == project.id ? "checkmark.circle.fill" : "circle.fill")
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    if let selectedProject {
                        Circle()
                            .fill(selectedProject.color.tint)
                            .frame(width: 9, height: 9)
                        Text(selectedProject.name)
                            .foregroundStyle(DevcomTheme.ink)
                    } else {
                        Text("No project")
                            .foregroundStyle(DevcomTheme.muted)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DevcomTheme.muted)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct ActionResultView: View {
    let result: ActionRunResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        Image(systemName: result.ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(result.ok ? .green : .orange)
                        VStack(alignment: .leading) {
                            Text("HTTP \(result.status)").font(.title2.bold())
                            Text("\(result.durationMs) ms").foregroundStyle(DevcomTheme.muted)
                        }
                    }
                    if !result.response.isEmpty {
                        Text(result.response)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(DevcomTheme.canvas, in: RoundedRectangle(cornerRadius: 12))
                    }
                    if result.truncated { Text("Response preview was limited to 64 KB.").font(.caption).foregroundStyle(DevcomTheme.muted) }
                }
                .padding(20)
            }
            .navigationTitle("Action result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
