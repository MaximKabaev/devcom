import SwiftUI

struct LoginView: View {
    @Bindable var model: AppModel
    @State private var server = ""
    @State private var username = "admin"
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case server, username, password }

    var body: some View {
        ZStack {
            DevcomTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    brand
                    Spacer(minLength: 54)
                    Text("Your systems,\none tap away.")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .tracking(-1.4)
                        .foregroundStyle(DevcomTheme.ink)
                    Text("Connect this phone to your private Devcom server.")
                        .font(.body)
                        .foregroundStyle(DevcomTheme.muted)
                        .padding(.top, 14)

                    VStack(spacing: 14) {
                        field("Server URL", text: $server, prompt: "https://devcom.example.com", field: .server)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        field("Username", text: $username, prompt: "admin", field: .username)
                            .textInputAutocapitalization(.never)
                        SecureField("Password", text: $password, prompt: Text("Password"))
                            .focused($focusedField, equals: .password)
                            .textContentType(.password)
                            .padding(16)
                            .background(DevcomTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 34)

                    Button {
                        Task { _ = await model.login(server: server, username: username, password: password) }
                    } label: {
                        HStack {
                            if model.isLoading { ProgressView().tint(.white) }
                            Text(model.isLoading ? "Connecting…" : "Connect")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(17)
                        .background(DevcomTheme.ink, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(server.isEmpty || username.isEmpty || password.isEmpty || model.isLoading)
                    .opacity(server.isEmpty || username.isEmpty || password.isEmpty ? 0.45 : 1)
                    .padding(.top, 18)
                }
                .padding(24)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
        .devcomErrorAlert(model: model)
    }

    private var brand: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(DevcomTheme.ink)
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
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, field: Field) -> some View {
        TextField(label, text: text, prompt: Text(prompt))
            .focused($focusedField, equals: field)
            .textContentType(field == .username ? .username : .URL)
            .padding(16)
            .background(DevcomTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

