import SwiftUI

struct LogView: View {
    let entries: [HistoryEntry]
    @State private var kind: LogKind = .all
    @State private var result: LogResult = .all
    @State private var origin: LogOriginFilter = .all
    @State private var query = ""
    @State private var expandedEntries: Set<String> = []

    private enum LogKind: String, CaseIterable, Identifiable {
        case all = "All", actions = "Actions", listeners = "Listeners"
        var id: String { rawValue }
        func matches(_ entry: HistoryEntry) -> Bool {
            switch self {
            case .all: true
            case .actions: !entry.isNotification
            case .listeners: entry.isNotification
            }
        }
    }

    private enum LogResult: String, CaseIterable, Identifiable {
        case all = "Any result", succeeded = "Succeeded", failed = "Failed"
        var id: String { rawValue }
        func matches(_ entry: HistoryEntry) -> Bool {
            switch self {
            case .all: true
            case .succeeded: entry.isSuccess
            case .failed: entry.isFailure
            }
        }
    }

    private enum LogOriginFilter: String, CaseIterable, Identifiable {
        case all = "Any origin", app = "App", external = "External", scheduled = "Scheduled"
        var id: String { rawValue }
        func matches(_ entry: HistoryEntry) -> Bool {
            switch self {
            case .all: true
            case .app: entry.origin == .app
            case .external: entry.origin == .external
            case .scheduled: entry.origin == .scheduled
            }
        }
    }

    private var filteredEntries: [HistoryEntry] {
        let matching = entries.filter { kind.matches($0) && result.matches($0) && origin.matches($0) }
            .filter { query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(query) }
        // Parse each timestamp once rather than on every comparison.
        return matching.map { ($0, $0.date) }.sorted { $0.1 > $1.1 }.map(\.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    chipGroup(LogKind.allCases, selection: $kind)
                    Divider().frame(height: 20)
                    chipGroup(LogResult.allCases, selection: $result)
                    Divider().frame(height: 20)
                    chipGroup(LogOriginFilter.allCases, selection: $origin)
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
                let visible = filteredEntries
                if visible.isEmpty {
                    ContentUnavailableView(
                        entries.isEmpty ? "No log entries" : "No matching entries",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(entries.isEmpty
                            ? "Action and listener activity will appear here."
                            : "Try a different filter or search.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(visible) { entry in
                        LogEntryRow(
                            entry: entry,
                            isExpanded: expandedEntries.contains(entry.id),
                            toggle: {
                                if expandedEntries.contains(entry.id) { expandedEntries.remove(entry.id) }
                                else { expandedEntries.insert(entry.id) }
                            }
                        )
                        .listRowBackground(DevcomTheme.surface)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func chipGroup<Option: Identifiable & RawRepresentable & Equatable>(
        _ options: [Option], selection: Binding<Option>
    ) -> some View where Option.RawValue == String {
        ForEach(options) { option in
            Button(option.rawValue) { selection.wrappedValue = option }
                .font(.caption.weight(.semibold))
                .foregroundStyle(selection.wrappedValue == option ? DevcomTheme.ink : DevcomTheme.muted)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    selection.wrappedValue == option ? DevcomTheme.outbound.opacity(0.14) : DevcomTheme.surface,
                    in: Capsule()
                )
        }
    }
}

private struct LogEntryRow: View {
    let entry: HistoryEntry
    let isExpanded: Bool
    let toggle: () -> Void

    private var accent: Color { entry.isNotification ? DevcomTheme.inbound : DevcomTheme.outbound }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: toggle) { header }
                .buttonStyle(.plain)
            if isExpanded { details }
        }
        .padding(.vertical, 6)
    }

    // MARK: Collapsed row

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.isNotification ? "bell.fill" : "bolt.fill")
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DevcomTheme.ink)
                preview
                HStack(spacing: 6) {
                    Text(statusText).foregroundStyle(entry.isFailure ? .red : DevcomTheme.muted)
                    Text("·").foregroundStyle(DevcomTheme.muted)
                    Label(originSummary, systemImage: entry.originSymbol).foregroundStyle(DevcomTheme.muted)
                }
                .font(.caption)
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DevcomTheme.ink)
                Text(entry.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(DevcomTheme.muted)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DevcomTheme.muted)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// What was said (notifications) or what was called (actions).
    @ViewBuilder private var preview: some View {
        if entry.isNotification {
            if let message = entry.message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(DevcomTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        } else if let request = requestSummary {
            Text(request)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(DevcomTheme.muted)
                .lineLimit(1)
        }
    }

    private var statusText: String {
        let status = (entry.status ?? "recorded").capitalized
        return entry.statusCode.map { "\(status) · HTTP \($0)" } ?? status
    }

    /// "API · 203.0.113.5" — enough to tell callers apart without opening the row.
    private var originSummary: String {
        [entry.originTitle, entry.caller?.ip].compactMap { $0 }.joined(separator: " · ")
    }

    private var requestSummary: String? {
        guard let url = entry.url, !url.isEmpty else { return nil }
        return "\(entry.method ?? "GET")  \(url)"
    }

    // MARK: Expanded detail

    @ViewBuilder private var details: some View {
        if entry.isNotification { notificationDetails } else { actionDetails }
        if let error = entry.error, !error.isEmpty {
            detailBlock(title: "Failure", text: error, color: .red)
        }
        originBlock
    }

    @ViewBuilder private var notificationDetails: some View {
        if let title = entry.title, !title.isEmpty, title != entry.displayName {
            detailBlock(title: "Title", text: title, color: DevcomTheme.muted)
        }
        if let message = entry.message, !message.isEmpty {
            detailBlock(title: "Message", text: message, color: DevcomTheme.muted, monospaced: false)
        } else {
            Text("The message text was not recorded for this entry.")
                .font(.caption)
                .foregroundStyle(DevcomTheme.muted)
        }
        if let report = entry.deliveryReport {
            deliverySummary(report)
        } else if let payload = entry.formattedResponse {
            detailBlock(title: "Return payload", text: payload, color: DevcomTheme.muted)
        }
    }

    @ViewBuilder private var actionDetails: some View {
        if let request = requestSummary {
            detailBlock(title: "Request", text: request, color: DevcomTheme.muted)
        }
        if let payload = entry.formattedResponse {
            detailBlock(
                title: entry.statusCode.map { "Response · HTTP \($0)" } ?? "Response",
                text: payload,
                color: DevcomTheme.muted
            )
        }
    }

    private func deliverySummary(_ report: DeliveryReport) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Delivery").font(.caption.weight(.semibold)).foregroundStyle(DevcomTheme.muted)
            VStack(alignment: .leading, spacing: 5) {
                if let devices = report.devices {
                    Label(
                        "Delivered to \(report.delivered ?? 0) of \(devices) device\(devices == 1 ? "" : "s")",
                        systemImage: (report.failed ?? 0) == 0 ? "checkmark.circle" : "exclamationmark.triangle"
                    )
                    .foregroundStyle((report.failed ?? 0) == 0 ? DevcomTheme.ink : .red)
                }
                ForEach(Array((report.errors ?? []).enumerated()), id: \.offset) { _, failure in
                    Text("\(failure.reason) × \(failure.count)").foregroundStyle(.red)
                }
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(DevcomTheme.canvas, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Who triggered the entry and from where. Older entries only know the
    /// coarse source, so the block says so instead of guessing.
    private var originBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Origin").font(.caption.weight(.semibold)).foregroundStyle(DevcomTheme.muted)
            VStack(alignment: .leading, spacing: 6) {
                infoRow("Via", entry.originTitle)
                if let client = entry.caller?.client, !client.isEmpty { infoRow("Client", client) }
                if let ip = entry.caller?.ip, !ip.isEmpty { infoRow("Address", ip) }
                if let agent = entry.caller?.userAgent, !agent.isEmpty { infoRow("User agent", agent) }
                infoRow("Time", entry.date.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().second()))
                if let durationMs = entry.durationMs { infoRow("Duration", "\(durationMs) ms") }
                if entry.originIsPartial {
                    Text("This entry predates caller tracking, so the machine and address were not recorded.")
                        .font(.caption2)
                        .foregroundStyle(DevcomTheme.muted)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(DevcomTheme.canvas, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .foregroundStyle(DevcomTheme.muted)
                .frame(width: 74, alignment: .leading)
            Text(value)
                .foregroundStyle(DevcomTheme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
    }

    private func detailBlock(title: String, text: String, color: Color, monospaced: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(color)
            Text(text)
                .font(monospaced ? .system(.caption, design: .monospaced) : .callout)
                .foregroundStyle(DevcomTheme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(DevcomTheme.canvas, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
