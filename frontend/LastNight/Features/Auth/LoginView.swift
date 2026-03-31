import SwiftUI
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingUsernameSetup = false
    @State private var pendingFirebaseUser: FirebaseAuth.User?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 8) {
                    Text("last night")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                    Text("capture the night, relive it tomorrow")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(spacing: 16) {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    GoogleSignInButton(scheme: .light, style: .wide) {
                        signInWithGoogle()
                    }
                    .frame(height: 54)
                    .cornerRadius(27)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .sheet(isPresented: $showingUsernameSetup) {
            if let firebaseUser = pendingFirebaseUser {
                UsernameSetupView(firebaseUser: firebaseUser)
                    .environmentObject(appState)
            }
        }
    }

    private func signInWithGoogle() {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error {
                errorMessage = error.localizedDescription
                return
            }
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else { return }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error {
                    errorMessage = error.localizedDescription
                    return
                }
                guard let firebaseUser = authResult?.user else { return }

                Task {
                    do {
                        let dbUser = try await APIClient.shared.syncUser()
                        appState.currentUser = dbUser
                        appState.isAuthenticated = true
                    } catch APIError.notFound {
                        pendingFirebaseUser = firebaseUser
                        showingUsernameSetup = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
