import SwiftUI

struct GroupFeedView: View {
    let group: Group
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var showingCamera = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else if photos.isEmpty {
                VStack(spacing: 12) {
                    Text("no photos yet")
                        .foregroundColor(.gray)
                    Text("be the first to capture the night")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { photo in
                            PhotoGridCell(photo: photo)
                        }
                    }
                }
            }

            // Camera button
            VStack {
                Spacer()
                Button {
                    showingCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                        .frame(width: 64, height: 64)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPhotos() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = group.inviteCode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text(group.inviteCode)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(groupId: group.id, onPhotoTaken: { newPhoto in
                photos.insert(newPhoto, at: 0)
            })
        }
    }

    private func loadPhotos() async {
        do {
            photos = try await APIClient.shared.getPhotos(groupId: group.id)
        } catch {
            print("Error loading photos:", error)
        }
        isLoading = false
    }
}

struct PhotoGridCell: View {
    let photo: Photo

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .aspectRatio(1, contentMode: .fit)

            if let url = photo.url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.05)
                }
                .clipped()
                .blur(radius: photo.locked ? 12 : 0)
            }

            if photo.locked {
                Image(systemName: "lock.fill")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.title3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }
}
