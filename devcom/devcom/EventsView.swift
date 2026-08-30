import SwiftUI

struct EventsView: View {
    @Bindable var model: AppModel
    @State private var section: EventSection = .actions
    @State private var presentedSheet: Sheet?

    private enum Sheet: Identifiable {
        case createAction
        case createListener
        case editAction(ActionEvent)
        case editListener(Listener)
        case settings

        var id: String {
            switch self {
            case .createAction: "create-action"
            case .createListener: "create-listener"
            case .editAction(let action): "edit-action-\(action.id)"
            case .editListener(let listener): "edit-listener-\(listener.id)"
            case .settings: "settings"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DevcomTheme.canvas.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("Event direction", selection: $section) {
                        ForEach(EventSection.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    Group {
                        if section == .actions { actionsList }
                        else { listenersList }
                    }
                    .animation(.easeOut(duration: 0.18), value: section)
                }
            }
            .navigationTitle("DEVCOM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { presentedSheet = .settings } label: { Image(systemName: "slider.horizontal.3") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentedSheet = section == .actions ? .createAction : .createListener
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel(section == .actions ? "Create action" : "Create listener")
                }
            }
            .refreshable { await model.refresh() }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .createAction: ActionEditorView(model: model)
                case .createListener: ListenerEditorView(model: model)
                case .editAction(let action): ActionEditorView(model: model, action: action)
                case .editListener(let listener): ListenerEditorView(model: model, listener: listener)
                case .settings: SettingsView(model: model)
                }
            }
            .sheet(item: $model.runResult) { result in ActionResultView(result: result) }
            .devcomErrorAlert(model: model)
        }
        .tint(section == .actions ? DevcomTheme.outbound : DevcomTheme.inbound)
    }

    @ViewBuilder private var actionsList: some View {
        if model.actions.isEmpty && !model.isLoading {
            ContentUnavailableView(
                "No actions yet",
                systemImage: "arrow.up.right",
                description: Text("Create an action to call a service from this phone.")
            )
        } else {
            List {
                ForEach(model.actions) { action in
                    ActionRow(
                        action: action,
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
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder private var listenersList: some View {
        if model.listeners.isEmpty && !model.isLoading {
            ContentUnavailableView(
                "Nothing listening",
                systemImage: "arrow.down.left",
                description: Text("Create a listener, then POST to its URL from any service.")
            )
        } else {
            List {
                ForEach(model.listeners) { listener in
                    ListenerRow(listener: listener, edit: { presentedSheet = .editListener(listener) })
                        .listRowBackground(DevcomTheme.surface)
                        .swipeActions {
                            Button("Delete", role: .destructive) { Task { await model.deleteListener(listener) } }
                        }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
}

private struct ActionRow: View {
    let action: ActionEvent
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

private struct ListenerRow: View {
    let listener: Listener
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
