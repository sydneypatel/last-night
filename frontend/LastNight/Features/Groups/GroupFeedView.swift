import SwiftUI

struct GroupFeedView: View {
    let group: Group
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var showingCamera = false
    @State private var showCopied = false
    @State private var showingMembers = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Invite code bar
                        Button {
                            UIPasteboard.general.string = group.inviteCode
                            withAnimation { showCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showCopied = false }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .font(.caption)
                                Text(group.inviteCode)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(showCopied ? "copied!" : "tap to copy")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                        // Photo grid
                        if photos.isEmpty {
                            VStack(spacing: 12) {
                                Spacer().frame(height: 60)
                                Text("no photos yet")
                                    .foregroundColor(.gray)
                                Text("be the first to capture the night")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photos) { photo in
                                    PhotoGridCell(photo: photo)
                                }
                            }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingMembers = true
                } label: {
                    Image(systemName: "person.2.fill")
                }
            }
        }
        .task { await loadPhotos() }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(groupId: group.id, onPhotoTaken: { newPhoto in
                photos.insert(newPhoto, at: 0)
            })
        }
        .sheet(isPresented: $showingMembers) {
            MembersView(groupId: group.id)
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
