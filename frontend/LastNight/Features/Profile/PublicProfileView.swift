import SwiftUI

struct PublicProfileView: View {
    let username: String
    let displayName: String
    @State private var slots: [LNFeaturedSlot] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 10) {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 72, height: 72)
                            .overlay(
                                Text(displayName.prefix(1))
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )

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

                    // Featured grid
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
        .preferredColorScheme(.dark)
    }

    private func loadGrid() async {
        do {
            let fetchedSlots = try await APIClient.shared.getFeaturedGrid(username: username)
            // Fill missing slots
            slots = (1...9).map { pos in
                fetchedSlots.first(where: { $0.position == pos }) ?? LNFeaturedSlot(position: pos, photo: nil)
            }
        } catch {
            slots = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
        }
        isLoading = false
    }
}
