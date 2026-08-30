import SwiftUI

enum DevcomTheme {
    static let canvas = Color(light: 0xF4F6F8, dark: 0x101316)
    static let surface = Color(light: 0xFFFFFF, dark: 0x191D21)
    static let ink = Color(light: 0x111820, dark: 0xF2F5F7)
    static let muted = Color(light: 0x64717D, dark: 0x9BA6AF)
    static let outbound = Color(light: 0x1F6FEB, dark: 0x58A6FF)
    static let inbound = Color(light: 0xB86509, dark: 0xE5A84B)
}

private extension Color {
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}

struct ErrorAlert: ViewModifier {
    @Bindable var model: AppModel

    func body(content: Content) -> some View {
        content.alert(
            "Request failed",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("Dismiss", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }
}

extension View {
    func devcomErrorAlert(model: AppModel) -> some View { modifier(ErrorAlert(model: model)) }
}

