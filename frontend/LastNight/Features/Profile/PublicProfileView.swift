// CAN DELETE!! 

import SwiftUI

struct PublicProfileView: View {
    let username: String
    let displayName: String
    let avatarUrl: String?
    @State private var slots: [LNFeaturedSlot] = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
    @State private var isLoading = true
    @State private var showingAvatarFullScreen = false

    init(username: String, displayName: String, avatarUrl: String? = nil) {
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 10) {
                        SwiftUI.Group {
                            if let avatarUrl, let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.white.opacity(0.1))
                                        .overlay(
                                            Text(displayName.prefix(1))
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        )
                                }
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 72, height: 72)
                                    .overlay(
                                        Text(displayName.prefix(1))
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        .onTapGesture {
                            showingAvatarFullScreen = true
                        }

                        VStack(spacing: 4) {
                            Text(displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("@\(username)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                    HStack {
                        Text("my favorites:")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    if isLoading {
                        ProgressView().tint(.white).padding(.top, 40)
                    } else {
                        FeaturedGridView(slots: slots, isOwner: false)
                    }
                }
            }
        }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadGrid() }
        .fullScreenCover(isPresented: $showingAvatarFullScreen) {
            AvatarFullScreenView(
                avatarUrl: avatarUrl,
                fallbackInitial: String(displayName.prefix(1))
            )
        }
        .preferredColorScheme(.dark)
    }

    private func loadGrid() async {
        do {
            let fetched = try await APIClient.shared.getFeaturedGrid(username: username)
            slots = (1...9).map { pos in
                fetched.first(where: { $0.position == pos }) ?? LNFeaturedSlot(position: pos, photo: nil)
            }
        } catch {
            slots = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
        }
        isLoading = false
    }
}
