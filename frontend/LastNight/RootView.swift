import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        SwiftUI.Group {
            if appState.isLoading {
                SplashView()
            } else if appState.isAuthenticated, appState.currentUser != nil {
                if hasSeenOnboarding {
                    MainTabView()
                } else {
                    OnboardingView {
                        hasSeenOnboarding = true
                    }
                }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isAuthenticated)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("last night.")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}
