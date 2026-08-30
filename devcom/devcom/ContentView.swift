import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            if model.isAuthenticated {
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

#Preview {
    ContentView()
}
