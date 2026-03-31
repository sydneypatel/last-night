import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var myPhotos: [Photo] = []
    @State private var isLoading = true

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 10) {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(appState.currentUser?.displayName.prefix(1) ?? "?")
                                        .font(.title)
                                        .foregroundColor(.white)
                                )

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
                        .padding(.bottom, 20)

                        HStack {
                            Text("my top nights:")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)

                        if isLoading {
                            ProgressView().tint(.white).padding(.top, 40)
                        } else if myPhotos.isEmpty {
                            VStack(spacing: 8) {
                                Text("no photos yet")
                                    .foregroundColor(.gray)
                                Text("your unlocked photos will appear here")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                            .padding(.horizontal, 32)
                        } else {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(myPhotos) { photo in
                                    if let url = photo.url, let imageURL = URL(string: url) {
                                        AsyncImage(url: imageURL) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Color.white.opacity(0.05)
                                        }
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipped()
                                    }
                                }
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
            .task { await loadMyPhotos() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadMyPhotos() async {
        do {
            myPhotos = try await APIClient.shared.getLibrary()
        } catch {
            print("Error loading photos:", error)
        }
        isLoading = false
    }
}
