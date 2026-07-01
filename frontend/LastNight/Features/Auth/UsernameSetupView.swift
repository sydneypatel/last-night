import SwiftUI
import FirebaseAuth

struct UsernameSetupView: View {
    let firebaseUser: FirebaseAuth.User
    @EnvironmentObject var appState: AppState

    @State private var username = ""
    @State private var displayName = ""
    @State private var phoneNumber = ""
    @State private var acceptedTerms = false
    @State private var shareContacts = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingLegal = false
    @State private var legalPage: LegalSheetView.Page = .terms

    var canProceed: Bool {
        !username.isEmpty && !displayName.isEmpty && acceptedTerms
    }

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
                            TextField("your_handle", text: $username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("phone number")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("optional")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(4)
                        }
                        TextField("+1 (555) 000-0000", text: $phoneNumber)
                            .textFieldStyle(LNTextFieldStyle())
                            .keyboardType(.phonePad)
                    }

                    // Contacts opt-in — only show if phone number entered
                    if !phoneNumber.isEmpty {
                        Button {
                            shareContacts.toggle()
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                    if shareContacts {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white)
                                            .frame(width: 22, height: 22)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("find friends from your contacts")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Text("we'll never store your contacts or share them")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                        }
                        .padding(.top, 2)
                    }

                    // Terms & Conditions
                    Button {
                        acceptedTerms.toggle()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                if acceptedTerms {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }

                            HStack(spacing: 4) {
                                Text("I agree to the")
                                    .foregroundColor(.gray)
                                Text("Terms & Conditions")
                                    .foregroundColor(.white)
                                    .underline()
                                    .onTapGesture {
                                        legalPage = .terms
                                        showingLegal = true
                                    }
                                Text("and")
                                    .foregroundColor(.gray)
                                Text("Privacy Policy")
                                    .foregroundColor(.white)
                                    .underline()
                                    .onTapGesture {
                                        legalPage = .privacy
                                        showingLegal = true
                                    }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.top, 4)

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
                        ProgressView().tint(.black)
                    } else {
                        Text("let's go")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canProceed ? Color.white : Color.white.opacity(0.2))
                .foregroundColor(.black)
                .cornerRadius(14)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .disabled(!canProceed || isLoading)
            }
        }
        .sheet(isPresented: $showingLegal) {
            LegalSheetView(initialPage: legalPage)
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

                // Save phone hash if provided
                if !phoneNumber.isEmpty, let hash = ContactsMatcher.hashPhone(phoneNumber) {
                    try? await APIClient.shared.savePhoneHash(hash)
                }

                // Request contacts + match if opted in
                if shareContacts {
                    if let hashes = await ContactsMatcher.requestAndHashContacts() {
                        _ = try? await APIClient.shared.matchContacts(hashes: hashes)
                    }
                }

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
