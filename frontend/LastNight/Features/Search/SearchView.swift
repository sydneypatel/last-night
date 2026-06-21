import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var results: [User] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.black.ignoresSafeArea()

                if query.count < 2 {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 80)
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.3))
                        Text("search for people")
                            .foregroundColor(.gray)
                    }
                } else if isSearching {
                    ProgressView().tint(.white).padding(.top, 60)
                } else if results.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 80)
                        Text("no users found")
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { user in
                                NavigationLink(value: user.username) {
                                    SearchResultRow(user: user, onToggleFollow: { updated in
                                        if let idx = results.firstIndex(where: { $0.id == updated.id }) {
                                            results[idx] = updated
                                        }
                                    })
                                }
                                .buttonStyle(.plain)
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
            }
            .navigationTitle("search")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { username in
                UserProfileView(username: username)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "search by username")
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                guard newValue.count >= 2 else {
                    results = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await performSearch(newValue)
                }
            }
            .onChange(of: appState.pendingFollowUserId) { _, userId in
                guard let userId else { return }
                // Fetch the username for this userId then navigate
                Task {
                    do {
                        let user = try await APIClient.shared.getUser(id: userId)
                        await MainActor.run {
                            navigationPath.append(user.username)
                            appState.pendingFollowUserId = nil
                        }
                    } catch {
                        print("Error fetching follower profile:", error)
                        appState.pendingFollowUserId = nil
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func performSearch(_ q: String) async {
        isSearching = true
        do {
            results = try await APIClient.shared.searchUsers(query: q)
        } catch {
            print("Search error:", error)
        }
        isSearching = false
    }
}

struct SearchResultRow: View {
    let user: User
    var onToggleFollow: (User) -> Void
    @State private var isFollowing: Bool
    @State private var isLoading = false

    init(user: User, onToggleFollow: @escaping (User) -> Void) {
        self.user = user
        self.onToggleFollow = onToggleFollow
        _isFollowing = State(initialValue: user.isFollowing ?? false)
    }

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

            Button {
                toggleFollow()
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView().tint(isFollowing ? .white : .black)
                    } else {
                        Text(isFollowing ? "following" : "follow")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isFollowing ? .white : .black)
                    }
                }
                .frame(width: 84, height: 32)
                .background(isFollowing ? Color.white.opacity(0.15) : Color.white)
                .cornerRadius(16)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func toggleFollow() {
        isLoading = true
        Task {
            do {
                if isFollowing {
                    try await APIClient.shared.unfollowUser(id: user.id)
                } else {
                    try await APIClient.shared.followUser(id: user.id)
                }
                isFollowing.toggle()
                var updated = user
                updated.isFollowing = isFollowing
                onToggleFollow(updated)
            } catch {
                print("Follow toggle error:", error)
            }
            isLoading = false
        }
    }
}
