import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            if model.isRestoringSession {
                StartupLoadingView()
            } else if model.isAuthenticated {
                EventsView(model: model)
            } else {
                LoginView(model: model)
            }
        }
        .task {
            await model.restoreSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceivePushToken)) { notification in
            guard let token = notification.object as? String else { return }
            Task { await model.registerDevice(token: token) }
        }
    }
}

private struct StartupLoadingView: View {
    var body: some View {
        ZStack {
            DevcomTheme.canvas.ignoresSafeArea()

            VStack(spacing: 22) {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DevcomTheme.ink)
                        Image(systemName: "arrow.up.right.and.arrow.down.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DevcomTheme.canvas)
                    }
                    .frame(width: 38, height: 38)

                    Text("DEVCOM")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(DevcomTheme.ink)
                }

                ProgressView()
                    .tint(DevcomTheme.muted)
                    .accessibilityLabel("Loading Devcom")
            }
        }
    }
}

#Preview {
    ContentView()
}
