import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Action events", value: "\(model.actions.count)")
                    LabeledContent("Listeners", value: "\(model.listeners.count)")
                    LabeledContent("Projects", value: "\(model.projects.count)")
                }
                Section {
                    Button("Disconnect", role: .destructive) {
                        dismiss()
                        model.logout()
                    }
                } footer: {
                    Text("This removes the server session from this phone. Events remain on the server.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
