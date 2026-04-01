import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var featuredSlots: [LNFeaturedSlot] = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 10) {
                            if let avatarUrl = appState.currentUser?.avatarUrl,
                               let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.white.opacity(0.1))
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(appState.currentUser?.displayName.prefix(1) ?? "?")
                                            .font(.title)
                                            .foregroundColor(.white)
                                    )
                            }

                            VStack(spacing: 4) {
                                Text(appState.currentUser?.displayName ?? "")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("@\(appState.currentUser?.username ?? "")")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 24)

                        HStack {
                            Text("my favorites:")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            NavigationLink(destination: EditFeaturedView().environmentObject(appState)) {
                                Text("edit")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                        if isLoading {
                            ProgressView().tint(.white).padding(.top, 40)
                        } else {
                            NavigationLink(destination: EditFeaturedView().environmentObject(appState)) {
                                FeaturedGridView(slots: featuredSlots, isOwner: true)
                            }
                        }
                    }
                }
            }
            .navigationTitle("profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
            }
            .task { await loadFeatured() }
            .onAppear { Task { await loadFeatured() } }
        }
        .preferredColorScheme(.dark)
    }

    private func loadFeatured() async {
        guard let username = appState.currentUser?.username else {
            isLoading = false
            return
        }
        do {
            let fetched = try await APIClient.shared.getFeaturedGrid(username: username)
            featuredSlots = (1...9).map { pos in
                fetched.first(where: { $0.position == pos }) ?? LNFeaturedSlot(position: pos, photo: nil)
            }
        } catch {
            print("Error loading featured:", error)
        }
        isLoading = false
    }
}
