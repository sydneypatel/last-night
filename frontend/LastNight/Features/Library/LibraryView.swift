import SwiftUI

struct LibraryView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var selectedPhotoIndex: Int?

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
                            ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                                if let url = photo.url, let imageURL = URL(string: url) {
                                    GeometryReader { geo in
                                        AsyncImage(url: imageURL) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: geo.size.width, height: geo.size.width)
                                                .clipped()
                                        } placeholder: {
                                            Color.white.opacity(0.05)
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
                                    .onTapGesture {
                                        selectedPhotoIndex = index
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await loadLibrary()
                    }
                }
            }
            .navigationTitle("library")
            .task { await loadLibrary() }
//            .onAppear { Task { await loadLibrary() } }
            .sheet(isPresented: Binding(
                get: { selectedPhotoIndex != nil },
                set: { if !$0 { selectedPhotoIndex = nil } }
            )) {
                if let index = selectedPhotoIndex {
                    LibraryDetailView(photos: photos, startIndex: index)
                        .environmentObject(AppState())
                }
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
