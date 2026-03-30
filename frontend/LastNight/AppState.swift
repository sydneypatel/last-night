import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthState()
    }

    private func listenToAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            Task {
                if let firebaseUser = firebaseUser {
                    await self.syncUser(firebaseUser: firebaseUser)
                } else {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.isLoading = false
                }
            }
        }
    }

    private func syncUser(firebaseUser: FirebaseAuth.User) async {
        do {
            let user = try await APIClient.shared.syncUser()
            self.currentUser = user
            self.isAuthenticated = true
        } catch APIError.notFound {
            // User exists in Firebase but not in our DB yet — needs registration
            self.isAuthenticated = false
        } catch {
            print("Sync error:", error)
        }
        self.isLoading = false
    }

    func signOut() {
        try? Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
    }
}
