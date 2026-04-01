import SwiftUI

struct GroupFeedView: View {
    let group: Group
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var showingCamera = false
    @State private var showCopied = false
    @State private var showingMembers = false
    @State private var selectedPhoto: Photo?

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private var unlockLabel: String {
        switch group.unlockMode {
        case .sunrise:
            return "photos unlock at sunrise"
        case .sundayNight:
            return "photos unlock sunday night"
        case .custom:
            guard let unlockAt = group.unlockAt else { return "photos unlock at custom time" }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "unlocks \(formatter.string(from: unlockAt))"
        }
    }

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
                            HStack(spacing: 12) {
                                Image(systemName: "link")
                                    .font(.body)
                                Text("invite code:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(group.inviteCode)
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .tracking(2)
                                Spacer()
                                Text(showCopied ? "copied!" : "tap to copy")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(14)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        // Unlock time
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(unlockLabel)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

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
                                        .onTapGesture {
                                            if !photo.locked {
                                                selectedPhoto = photo
                                            }
                                        }
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
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, groupName: group.name)
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
