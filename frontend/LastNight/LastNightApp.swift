import SwiftUI
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    static weak var shared: AppDelegate?
    var appState: AppState?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppDelegate.shared = self
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestPushPermission(application)
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    private func requestPushPermission(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Push permission granted:", granted, error as Any)
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ APNs device token received")
        Messaging.messaging().apnsToken = deviceToken
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

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String
        
        DispatchQueue.main.async {
            if type == "photos_unlocked" || type == "member_joined" || type == "added_to_group",
               let groupId = userInfo["groupId"] as? String {
                AppDelegate.shared?.appState?.pendingGroupId = groupId
            } else if type == "new_follower",
                      let userId = userInfo["userId"] as? String {
                AppDelegate.shared?.appState?.pendingFollowUserId = userId
            } else if type == "admin_report" {
                AppDelegate.shared?.appState?.pendingAdminReport = true
            }
        }
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        AppState.latestFCMToken = fcmToken   // stash for post-auth registration
        Task {
            try? await APIClient.shared.registerDeviceToken(fcmToken, environment: "fcm")
        }
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
                .onAppear {
                    delegate.appState = appState
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        // Let Google Sign-In handle its own OAuth callback URLs first
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }

        // Universal link: last-night-app.com/join/<CODE>
        guard url.host == "last-night-app.com" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        // parts == ["join", "CODE"]
        if parts.count == 2, parts[0] == "join" {
            let code = parts[1]
            appState.handleInviteCode(code)
        }
    }
}
