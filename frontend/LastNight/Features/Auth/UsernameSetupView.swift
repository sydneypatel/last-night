import SwiftUI
import FirebaseAuth

struct UsernameSetupView: View {
    let firebaseUser: FirebaseAuth.User
    @EnvironmentObject var appState: AppState

    @State private var username = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("set up your profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("this is how your friends will find you")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 48)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("display name")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Your name", text: $displayName)
                            .textFieldStyle(LNTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("username")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack {
                            Text("@")
                                .foregroundColor(.gray)
                            TextField("yourhandle", text: $username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    register()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("let's go")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(14)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .disabled(isLoading || username.isEmpty || displayName.isEmpty)
            }
        }
    }

    private func register() {
        isLoading = true
        errorMessage = nil
        let tz = TimeZone.current.identifier

        Task {
            do {
                let user = try await APIClient.shared.register(
                    username: username,
                    displayName: displayName,
                    timezone: tz
                )
                appState.currentUser = user
                appState.isAuthenticated = true
            } catch APIError.badRequest(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = "Something went wrong, try again"
            }
            isLoading = false
        }
    }
}

struct LNTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .foregroundColor(.white)
    }
}
