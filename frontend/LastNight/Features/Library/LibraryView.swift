import SwiftUI

struct LibraryView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var selectedPhoto: Photo?

    private let columns = [GridItem(.flexible(), spacing: 2),
                           GridItem(.flexible(), spacing: 2),
                           GridItem(.flexible(), spacing: 2)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.white)
                } else if photos.isEmpty {
                    VStack(spacing: 8) {
                        Text("your library is empty")
                            .foregroundColor(.gray)
                        Text("save photos from your groups after they unlock")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 48)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photos) { photo in
                                if let url = photo.url, let imageURL = URL(string: url) {
                                    AsyncImage(url: imageURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.white.opacity(0.05)
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
                                    .onTapGesture {
                                        selectedPhoto = photo
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("library")
            .task { await loadLibrary() }
            .sheet(item: $selectedPhoto) { photo in
                LibraryDetailView(photo: photo)
                    .environmentObject(AppState())
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadLibrary() async {
        do {
            photos = try await APIClient.shared.getLibrary()
        } catch {
            print("Error loading library:", error)
        }
        isLoading = false
    }
}
