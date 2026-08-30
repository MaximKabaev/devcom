import SwiftUI

struct EventsView: View {
    @Bindable var model: AppModel
    @State private var section: EventSection = .actions
    @State private var presentedSheet: Sheet?

    private enum Sheet: Identifiable {
        case createAction, createListen, settings
        var id: Int {
            switch self { case .createAction: 0; case .createListen: 1; case .settings: 2 }
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
                        else { listensList }
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
                        presentedSheet = section == .actions ? .createAction : .createListen
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel(section == .actions ? "Create action" : "Create listen event")
                }
            }
            .refreshable { await model.refresh() }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .createAction: ActionEditorView(model: model)
                case .createListen: ListenEditorView(model: model)
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
                    ActionRow(action: action, isRunning: model.runningActionID == action.id) {
                        Task { await model.run(action) }
                    }
                        .listRowBackground(DevcomTheme.surface)
                        .swipeActions {
                            Button("Delete", role: .destructive) { Task { await model.deleteAction(action) } }
                        }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder private var listensList: some View {
        if model.listens.isEmpty && !model.isLoading {
            ContentUnavailableView(
                "Nothing listening",
                systemImage: "arrow.down.left",
                description: Text("Create a listen event, then POST to its URL from any service.")
            )
        } else {
            List {
                ForEach(model.listens) { listen in
                    ListenRow(listen: listen)
                        .listRowBackground(DevcomTheme.surface)
                        .swipeActions {
                            Button("Delete", role: .destructive) { Task { await model.deleteListen(listen) } }
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
    let run: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            signalRail(color: DevcomTheme.outbound, icon: "arrow.up.right")
            VStack(alignment: .leading, spacing: 5) {
                Text(action.name).font(.headline).foregroundStyle(DevcomTheme.ink)
                Text("\(action.method)  \(action.url)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DevcomTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
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

private struct ListenRow: View {
    let listen: ListenEvent
    @State private var copied = false

    var body: some View {
        HStack(spacing: 14) {
            signalRail(color: DevcomTheme.inbound, icon: "arrow.down.left")
            VStack(alignment: .leading, spacing: 5) {
                Text(listen.name).font(.headline).foregroundStyle(DevcomTheme.ink)
                Text(listen.webhookURL)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DevcomTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                UIPasteboard.general.string = listen.webhookURL
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 42, height: 42)
                    .background(DevcomTheme.inbound.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copied ? "Copied" : "Copy webhook URL")
        }
        .padding(.vertical, 7)
    }
}

private func signalRail(color: Color, icon: String) -> some View {
    ZStack {
        Capsule().fill(color.opacity(0.14)).frame(width: 34, height: 48)
        Capsule().fill(color).frame(width: 3, height: 28).offset(x: -10)
        Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
    }
}
