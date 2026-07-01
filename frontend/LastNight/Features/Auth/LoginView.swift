import SwiftUI
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingUsernameSetup = false
    @State private var pendingFirebaseUser: FirebaseAuth.User?
    @State private var errorMessage: String?
    @State private var currentNonce: String?
    @State private var appleDelegate: AppleSignInDelegate?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 8) {
                    Text("last night.")
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

                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            Image("google_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("sign in with google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(27)
                    }

                    Button {
                        signInWithApple()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18))
                                .foregroundColor(.black)
                            Text("sign in with apple")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(27)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .fullScreenCover(isPresented: $showingUsernameSetup) {
            if let firebaseUser = pendingFirebaseUser {
                UsernameSetupView(firebaseUser: firebaseUser)
                    .environmentObject(appState)
            }
        }
    }

    // MARK: - Google

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

            completeFirebaseSignIn(with: credential)
        }
    }

    // MARK: - Apple

    private func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let delegate = AppleSignInDelegate(
            onSuccess: { credential in
                completeFirebaseSignIn(with: credential)
            },
            onError: { message in
                if let message { errorMessage = message }
            },
            rawNonce: nonce
        )
        appleDelegate = delegate  // retain it

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
    }

    // MARK: - Shared Firebase handshake

    private func completeFirebaseSignIn(with credential: AuthCredential) {
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

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple Sign In delegate

final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let onSuccess: (AuthCredential) -> Void
    let onError: (String?) -> Void
    let rawNonce: String

    init(onSuccess: @escaping (AuthCredential) -> Void, onError: @escaping (String?) -> Void, rawNonce: String) {
        self.onSuccess = onSuccess
        self.onError = onError
        self.rawNonce = rawNonce
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            onError("Apple sign in failed")
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleIDCredential.fullName
        )
        onSuccess(credential)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Ignore user cancellation
        if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
            onError(nil)
            return
        }
        onError(error.localizedDescription)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
