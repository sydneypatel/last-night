import SwiftUI

enum FollowListMode {
    case followers
    case following
}

struct FollowListView: View {
    let userId: String
    let username: String
    @State var mode: FollowListMode
    @Environment(\.dismiss) var dismiss
    @State private var users: [User] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.white)
                } else if users.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 60)
                        Text(mode == .followers ? "no followers yet" : "not following anyone yet")
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(users) { user in
                                NavigationLink(destination: UserProfileView(username: user.username)) {
                                    FollowListRow(user: user)
                                }
                                .buttonStyle(.plain)
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
            }
            .navigationTitle("@\(username)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $mode) {
                        Text("followers").tag(FollowListMode.followers)
                        Text("following").tag(FollowListMode.following)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .task(id: mode) { await loadList() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadList() async {
        isLoading = true
        do {
            switch mode {
            case .followers:
                users = try await APIClient.shared.getFollowers(userId: userId)
            case .following:
                users = try await APIClient.shared.getFollowing(userId: userId)
            }
        } catch {
            print("Error loading \(mode):", error)
        }
        isLoading = false
    }
}

struct FollowListRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 14) {
            if let urlStr = user.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.1))
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(user.displayName.prefix(1))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
