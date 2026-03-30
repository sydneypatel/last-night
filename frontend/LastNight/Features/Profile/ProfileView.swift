import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Avatar
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(appState.currentUser?.displayName.prefix(1) ?? "?")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                        .padding(.top, 32)

                    VStack(spacing: 4) {
                        Text(appState.currentUser?.displayName ?? "")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text("@\(appState.currentUser?.username ?? "")")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button {
                        appState.signOut()
                    } label: {
                        Text("sign out")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("profile")
        }
        .preferredColorScheme(.dark)
    }
}
