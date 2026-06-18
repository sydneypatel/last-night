import SwiftUI
import FirebaseCore
import GoogleSignIn
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("🚀🚀🚀 APP DELEGATE LAUNCHED 🚀🚀🚀")
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        registerForPushNotifications(application)
        DispatchQueue.main.async {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    private func registerForPushNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings:", settings.authorizationStatus.rawValue)
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    print("Push permission granted:", granted, error as Any)
                    guard granted else { return }
                    DispatchQueue.main.async {
                        print("Calling registerForRemoteNotifications...")
                        application.registerForRemoteNotifications()
                    }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    print("Calling registerForRemoteNotifications...")
                    application.registerForRemoteNotifications()
                }
            default:
                print("Push notifications denied or restricted")
            }
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("✅ Device token:", token)
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        Task {
            try? await APIClient.shared.registerDeviceToken(token, environment: environment)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for push:", error)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct LastNightApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    init() {
        if let clientID = FirebaseApp.app()?.options.clientID {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
