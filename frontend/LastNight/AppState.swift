import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var pendingGroupId: String? = nil
    @Published var pendingFollowUserId: String? = nil
    @Published var pendingInviteCode: String? = nil

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
            // Process any invite that was tapped before sign-in completed
            await self.processPendingInviteIfReady()
        } catch APIError.notFound {
            self.currentUser = nil
            self.isAuthenticated = false
        } catch APIError.unauthorized {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await syncUser(firebaseUser: firebaseUser)
            return
        } catch {
            print("Sync error:", error)
            self.currentUser = nil
            self.isAuthenticated = false
        }
        self.isLoading = false
    }

    func signOut() {
        try? Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Deep link invite handling

    /// Called when a universal link with a join code is opened.
    func handleInviteCode(_ code: String) {
        pendingInviteCode = code
        Task { await processPendingInviteIfReady() }
    }

    /// Joins the group if the user is signed in; otherwise the code stays
    /// stashed until auth completes (then syncUser calls this again).
    func processPendingInviteIfReady() async {
        guard let code = pendingInviteCode else { return }
        guard isAuthenticated, currentUser != nil else { return }
        
        do {
            let (group, isMember) = try await APIClient.shared.getGroupByCode(code)
            pendingInviteCode = nil
            if isMember {
                // Already in — just navigate, no re-join
                pendingGroupId = group.id
            } else {
                let joined = try await APIClient.shared.joinGroup(inviteCode: code)
                pendingGroupId = joined.id
            }
        } catch {
            print("Invite resolve/join error:", error)
            pendingInviteCode = nil
        }
    }
}
