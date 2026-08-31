import SwiftUI

extension ProjectColor {
    var tint: Color {
        switch self {
        case .blue: .blue
        case .violet: .purple
        case .mint: .mint
        case .amber: .orange
        case .rose: .pink
        case .slate: .gray
        }
    }
}

struct ProjectManagerView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var presentedEditor: Editor?
    @State private var pendingDeletion: Project?

    private enum Editor: Identifiable {
        case create
        case edit(Project)

        var id: String {
            switch self {
            case .create: "create-project"
            case .edit(let project): "edit-project-\(project.id)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.projects.isEmpty {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: "folder",
                        description: Text("Create a project, then assign actions and listeners from their configuration screens.")
                    )
                } else {
                    List {
                        ForEach(model.projects) { project in
                            Button { presentedEditor = .edit(project) } label: {
                                HStack(spacing: 13) {
                                    Circle()
                                        .fill(project.color.tint)
                                        .frame(width: 12, height: 12)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(project.name)
                                            .font(.headline)
                                            .foregroundStyle(DevcomTheme.ink)
                                        Text(summary(for: project))
                                            .font(.caption)
                                            .foregroundStyle(DevcomTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DevcomTheme.muted.opacity(0.65))
                                }
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Delete", role: .destructive) { pendingDeletion = project }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(DevcomTheme.canvas)
                }
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { presentedEditor = .create } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Create project")
                }
            }
            .sheet(item: $presentedEditor) { editor in
                switch editor {
                case .create: ProjectEditorView(model: model)
                case .edit(let project): ProjectEditorView(model: model, project: project)
                }
            }
            .confirmationDialog(
                "Delete \(pendingDeletion?.name ?? "project")?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete project", role: .destructive) {
                    guard let project = pendingDeletion else { return }
                    pendingDeletion = nil
                    Task { await model.deleteProject(project) }
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("Its actions and listeners will remain, with no project assigned.")
            }
        }
    }

    private func summary(for project: Project) -> String {
        let actionCount = model.actions.filter { $0.projectId == project.id }.count
        let listenerCount = model.listeners.filter { $0.projectId == project.id }.count
        return "\(actionCount) actions · \(listenerCount) listeners"
    }
}

private struct ProjectEditorView: View {
    @Bindable var model: AppModel
    let project: Project?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: ProjectColor
    @State private var isSaving = false

    init(model: AppModel, project: Project? = nil) {
        self.model = model
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _color = State(initialValue: project?.color ?? .blue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Name", text: $name, prompt: Text("Home lab"))
                }

                Section("Color") {
                    HStack(spacing: 0) {
                        ForEach(ProjectColor.allCases) { option in
                            Button { color = option } label: {
                                ZStack {
                                    Circle()
                                        .fill(option.tint)
                                        .frame(width: 30, height: 30)
                                    if color == option {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.rawValue.capitalized)
                            .accessibilityAddTraits(color == option ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle(project == nil ? "New project" : "Edit project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let saved: Bool
            if let project {
                saved = await model.updateProject(project, name: cleanName, color: color)
            } else {
                saved = await model.createProject(name: cleanName, color: color)
            }
            isSaving = false
            if saved { dismiss() }
        }
    }
}
