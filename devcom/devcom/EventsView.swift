import SwiftUI

struct EventsView: View {
    @Bindable var model: AppModel
    @State private var page: AppPage = .actions
    @State private var projectFilter: ProjectFilter = .all
    @State private var presentedSheet: Sheet?

    private enum ProjectFilter: Hashable {
        case all
        case project(String)
        case unfiled
    }

    private enum AppPage: String, CaseIterable, Identifiable {
        case actions = "Actions", listeners = "Listeners", log = "Log"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .actions: "bolt.fill"
            case .listeners: "bell.fill"
            case .log: "clock.arrow.circlepath"
            }
        }
    }

    private enum Sheet: Identifiable {
        case createAction
        case createListener
        case editAction(ActionEvent)
        case editListener(Listener)
        case projects
        case settings

        var id: String {
            switch self {
            case .createAction: "create-action"
            case .createListener: "create-listener"
            case .editAction(let action): "edit-action-\(action.id)"
            case .editListener(let listener): "edit-listener-\(listener.id)"
            case .projects: "projects"
            case .settings: "settings"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DevcomTheme.canvas.ignoresSafeArea()
                VStack(spacing: 0) {
                    if page != .log && !model.projects.isEmpty {
                        projectBar
                    }

                    Group {
                        switch page {
                        case .actions: actionsList
                        case .listeners: listenersList
                        case .log: logView
                        }
                    }
                    .animation(.easeOut(duration: 0.18), value: page)
                    bottomBar
                }
            }
            .navigationTitle("DEVCOM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { presentedSheet = .settings } label: { Image(systemName: "slider.horizontal.3") }
                    Button { presentedSheet = .projects } label: { Image(systemName: "folder") }
                        .accessibilityLabel("Manage projects")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentedSheet = page == .actions ? .createAction : .createListener
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel(page == .actions ? "Create action" : "Create listener")
                    .disabled(page == .log)
                }
            }
            .refreshable { await model.refresh() }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .createAction: ActionEditorView(model: model, initialProjectId: activeProjectId)
                case .createListener: ListenerEditorView(model: model, initialProjectId: activeProjectId)
                case .editAction(let action): ActionEditorView(model: model, action: action)
                case .editListener(let listener): ListenerEditorView(model: model, listener: listener)
                case .projects: ProjectManagerView(model: model)
                case .settings: SettingsView(model: model)
                }
            }
            .sheet(item: $model.runResult) { result in ActionResultView(result: result) }
            .devcomErrorAlert(model: model)
            .onChange(of: model.projects.map(\.id)) { _, projectIDs in
                if case .project(let id) = projectFilter, !projectIDs.contains(id) { projectFilter = .all }
            }
        }
        .tint(page == .actions ? DevcomTheme.outbound : page == .listeners ? DevcomTheme.inbound : DevcomTheme.ink)
    }

    private var filteredActions: [ActionEvent] {
        model.actions.filter { matches(projectId: $0.projectId) }
    }

    private var activeProjectId: String? {
        if case .project(let id) = projectFilter { return id }
        return nil
    }

    private var filteredListeners: [Listener] {
        model.listeners.filter { matches(projectId: $0.projectId) }
    }

    private var bottomBar: some View {
        HStack(spacing: 6) {
            ForEach(AppPage.allCases) { destination in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { page = destination }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: destination.icon).font(.system(size: 15, weight: .semibold))
                        if page == destination { Text(destination.rawValue).font(.caption.weight(.semibold)) }
                    }
                    .foregroundStyle(page == destination ? DevcomTheme.ink : DevcomTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .contentShape(Rectangle())
                    .background(page == destination ? DevcomTheme.surface.opacity(0.7) : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(destination.rawValue)
                .accessibilityAddTraits(page == destination ? .isSelected : [])
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 10)
        .padding(.bottom, 5)
    }

    private func matches(projectId: String?) -> Bool {
        switch projectFilter {
        case .all: true
        case .project(let id): projectId == id
        case .unfiled: projectId == nil
        }
    }

    private func project(for projectId: String?) -> Project? {
        guard let projectId else { return nil }
        return model.projects.first { $0.id == projectId }
    }

    private var projectBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                projectFilterButton(title: "All", color: DevcomTheme.muted, filter: .all)
                ForEach(model.projects) { project in
                    projectFilterButton(title: project.name, color: project.color.tint, filter: .project(project.id))
                }
                projectFilterButton(title: "Unfiled", color: DevcomTheme.muted, filter: .unfiled)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .frame(height: 46)
    }

    private func projectFilterButton(title: String, color: Color, filter: ProjectFilter) -> some View {
        let selected = projectFilter == filter
        return Button { projectFilter = filter } label: {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(selected ? DevcomTheme.ink : DevcomTheme.muted)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(selected ? color.opacity(0.14) : DevcomTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(selected ? color.opacity(0.28) : DevcomTheme.muted.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var actionsList: some View {
        if filteredActions.isEmpty && !model.isLoading {
            ContentUnavailableView(
                model.actions.isEmpty ? "No actions yet" : "No actions here",
                systemImage: model.actions.isEmpty ? "arrow.up.right" : "folder",
                description: Text(model.actions.isEmpty ? "Create an action to call a service from this phone." : "Assign an action to this project from its configuration screen.")
            )
        } else {
            List {
                ForEach(filteredActions) { action in
                    ActionRow(
                        action: action,
                        project: project(for: action.projectId),
                        isRunning: model.runningActionID == action.id,
                        edit: { presentedSheet = .editAction(action) },
                        run: { Task { await model.run(action) } }
                    )
                        .listRowBackground(DevcomTheme.surface)
                        .swipeActions {
                            Button("Delete", role: .destructive) { Task { await model.deleteAction(action) } }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder private var listenersList: some View {
        if filteredListeners.isEmpty && !model.isLoading {
            ContentUnavailableView(
                model.listeners.isEmpty ? "Nothing listening" : "No listeners here",
                systemImage: model.listeners.isEmpty ? "arrow.down.left" : "folder",
                description: Text(model.listeners.isEmpty ? "Create a listener, then POST to its URL from any service." : "Assign a listener to this project from its configuration screen.")
            )
        } else {
            List {
                ForEach(filteredListeners) { listener in
                    ListenerRow(listener: listener, project: project(for: listener.projectId), edit: { presentedSheet = .editListener(listener) })
                        .listRowBackground(DevcomTheme.surface)
                        .swipeActions {
                            Button("Delete", role: .destructive) { Task { await model.deleteListener(listener) } }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var logView: some View {
        LogView(entries: model.history)
    }
}

private struct LogView: View {
    let entries: [HistoryEntry]
    @State private var filter: LogFilter = .all
    @State private var status: LogStatus = .all
    @State private var query = ""

    private enum LogFilter: String, CaseIterable, Identifiable {
        case all = "All", actions = "Actions", listeners = "Listeners"
        var id: String { rawValue }
    }
    private enum LogStatus: String, CaseIterable, Identifiable {
        case all = "Any result", succeeded = "Succeeded", failed = "Failed"
        var id: String { rawValue }
    }
    private var filteredEntries: [HistoryEntry] {
        entries.filter { filter == .all || ($0.displayKind.lowercased() == filter.rawValue.lowercased()) }
            .filter { status == .all || $0.status?.lowercased() == status.rawValue.lowercased() }
            .filter { query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query) }
            .sorted { date($0.timestamp) > date($1.timestamp) }
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    filterChip("All", selected: filter == .all) { filter = .all }
                    filterChip("Actions", selected: filter == .actions) { filter = .actions }
                    filterChip("Listeners", selected: filter == .listeners) { filter = .listeners }
                    Divider().frame(height: 20)
                    filterChip("Any result", selected: status == .all) { status = .all }
                    filterChip("Succeeded", selected: status == .succeeded) { status = .succeeded }
                    filterChip("Failed", selected: status == .failed) { status = .failed }
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DevcomTheme.muted)
                        TextField("Search log", text: $query)
                            .textFieldStyle(.plain)
                            .frame(width: 110)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(DevcomTheme.surface, in: Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
            }
            List {
                if filteredEntries.isEmpty {
                    ContentUnavailableView("No log entries", systemImage: "clock.arrow.circlepath", description: Text("Action and listener activity will appear here.")).listRowBackground(Color.clear)
                } else {
                    ForEach(filteredEntries) { entry in
                        HStack(spacing: 12) {
                            let isAction = entry.displayKind == "Action"
                            let color = isAction ? DevcomTheme.outbound : DevcomTheme.inbound
                            Image(systemName: isAction ? "bolt.fill" : "bell.fill").foregroundStyle(color).frame(width: 28, height: 28).background(color.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(DevcomTheme.ink)
                                Text("\(entry.displayKind) · \(entry.status ?? "recorded")").font(.caption).foregroundStyle(DevcomTheme.muted)
                            }
                            Spacer(); Text(date(entry.timestamp), style: .relative).font(.caption2).foregroundStyle(DevcomTheme.muted)
                        }.padding(.vertical, 5).listRowBackground(DevcomTheme.surface)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? DevcomTheme.ink : DevcomTheme.muted)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(selected ? DevcomTheme.outbound.opacity(0.14) : DevcomTheme.surface, in: Capsule())
    }
    private func date(_ value: String?) -> Date {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let value else { return Date.distantPast }
        return formatter.date(from: value) ?? Date.distantPast
    }
}

private struct ActionRow: View {
    let action: ActionEvent
    let project: Project?
    let isRunning: Bool
    let edit: () -> Void
    let run: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: edit) {
                HStack(spacing: 14) {
                    eventBadge(color: DevcomTheme.outbound, icon: "bolt.fill")
                    VStack(alignment: .leading, spacing: 5) {
                        Text(action.name).font(.headline).foregroundStyle(DevcomTheme.ink)
                        Text("\(action.method)  \(action.url)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DevcomTheme.muted)
                            .lineLimit(1)
                        ActionScheduleIndicators(schedules: action.schedule)
                        if let project { ProjectTag(project: project) }
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DevcomTheme.muted.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(action.name)")
            Button {
                run()
            } label: {
                Group { if isRunning { ProgressView() } else { Image(systemName: "play.fill") } }
                    .frame(width: 42, height: 42)
                    .background(DevcomTheme.outbound.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isRunning)
            .accessibilityLabel("Run \(action.name)")
        }
        .padding(.vertical, 7)
    }
}

private struct ActionScheduleIndicators: View {
    let schedules: ActionSchedules

    var body: some View {
        HStack(spacing: 6) {
            if schedules.once != nil { scheduleBadge("Once", icon: "calendar") }
            if schedules.recurring != nil { scheduleBadge("Recurring", icon: "arrow.triangle.2.circlepath") }
        }
    }

    private func scheduleBadge(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.caption2.weight(.semibold)).foregroundStyle(DevcomTheme.muted)
            .padding(.horizontal, 7).frame(height: 22).background(DevcomTheme.canvas, in: Capsule())
    }
}

private struct ListenerRow: View {
    let listener: Listener
    let project: Project?
    let edit: () -> Void
    @State private var copied = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: edit) {
                HStack(spacing: 14) {
                    eventBadge(color: DevcomTheme.inbound, icon: "bell.fill")
                    VStack(alignment: .leading, spacing: 5) {
                        Text(listener.name).font(.headline).foregroundStyle(DevcomTheme.ink)
                        Text(listener.webhookURL)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DevcomTheme.muted)
                            .lineLimit(1)
                        if let project { ProjectTag(project: project) }
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DevcomTheme.muted.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(listener.name)")
            Button {
                UIPasteboard.general.string = listener.webhookURL
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            } label: {
                Label(copied ? "Copied" : "Copy URL", systemImage: copied ? "checkmark" : "link")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                    .background(DevcomTheme.inbound.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copied ? "Copied" : "Copy webhook URL")
        }
        .padding(.vertical, 7)
    }
}

private struct ProjectTag: View {
    let project: Project

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(project.color.tint).frame(width: 6, height: 6)
            Text(project.name)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(DevcomTheme.muted)
    }
}

private func eventBadge(color: Color, icon: String) -> some View {
    ZStack {
        Circle().fill(color.opacity(0.12))
        Circle().stroke(color.opacity(0.22), lineWidth: 1)
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
    }
    .frame(width: 38, height: 38)
}
