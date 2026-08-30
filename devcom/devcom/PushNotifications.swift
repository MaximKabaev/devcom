import UIKit

extension Notification.Name {
    static let didReceivePushToken = Notification.Name("didReceivePushToken")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "pushDeviceToken")
        NotificationCenter.default.post(name: .didReceivePushToken, object: token)
    }
}

