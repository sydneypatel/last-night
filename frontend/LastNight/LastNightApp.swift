import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct LastNightApp: App {
    @StateObject private var appState = AppState()

    init() {
        FirebaseApp.configure()
        
        // Configure Google Sign-In with client ID from plist
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
