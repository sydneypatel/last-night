import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingChangeName = false
    @State private var showingDeleteAccount = false
    @State private var newDisplayName = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Button {
                        newDisplayName = appState.currentUser?.displayName ?? ""
                        showingChangeName = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("change display name")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(12)
                    }

                    Button {
                        appState.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("sign out")
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.bottom, 8)
                }

                Button {
                    showingDeleteAccount = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("delete account")
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("change display name", isPresented: $showingChangeName) {
            TextField("display name", text: $newDisplayName)
            Button("save") { updateDisplayName() }
            Button("cancel", role: .cancel) {}
        }
        .alert("delete account", isPresented: $showingDeleteAccount) {
            Button("delete", role: .destructive) { deleteAccount() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this will permanently delete your account and all your data. this cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }

    private func updateDisplayName() {
        guard !newDisplayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            do {
                let user = try await APIClient.shared.updateProfile(displayName: newDisplayName)
                await MainActor.run { appState.currentUser = user }
            } catch {
                errorMessage = "couldn't update name, try again"
            }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await APIClient.shared.deleteAccount()
                await MainActor.run { appState.signOut() }
            } catch {
                errorMessage = "couldn't delete account, try again"
            }
        }
    }
}
