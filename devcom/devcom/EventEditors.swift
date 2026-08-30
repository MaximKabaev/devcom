import SwiftUI

struct ActionEditorView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var method = "POST"
    @State private var url = ""
    @State private var headers = "{\n  \"Content-Type\": \"application/json\"\n}"
    @State private var requestBody = ""
    @State private var validationMessage: String?
    @State private var isSaving = false

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE"]

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
            .navigationTitle("New action")
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
            let saved = await model.createAction(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                method: method,
                url: url,
                headers: object,
                body: requestBody.isEmpty ? nil : requestBody
            )
            isSaving = false
            if saved { dismiss() }
        }
    }
}

struct ListenEditorView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Deploy finished"))
                } footer: {
                    Text("After saving, copy the secret URL and POST a title and message to it.")
                }

                Section("Accepted payload") {
                    Text("{\n  \"title\": \"Deploy complete\",\n  \"message\": \"api.example.com is live\"\n}")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(DevcomTheme.muted)
                }
            }
            .navigationTitle("New listen event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        isSaving = true
                        Task {
                            let saved = await model.createListen(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
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
