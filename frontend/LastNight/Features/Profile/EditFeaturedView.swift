import SwiftUI

struct EditFeaturedView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var slots: [LNFeaturedSlot] = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
    @State private var myPhotos: [Photo] = []
    @State private var selectedSlot: LNFeaturedSlot?
    @State private var isLoading = true
    @State private var showingPhotoPicker = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Text("tap a slot to add or change a photo")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)

                        if isLoading {
                            ProgressView().tint(.white).padding(.top, 40)
                        } else {
                            FeaturedGridView(slots: slots, isOwner: true) { slot in
                                selectedSlot = slot
                                showingPhotoPicker = true
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
            }
            .navigationTitle("edit featured")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .task { await loadData() }
            .sheet(isPresented: $showingPhotoPicker) {
                if let slot = selectedSlot {
                    PhotoPickerView(
                        slot: slot,
                        photos: myPhotos,
                        onSelect: { photoId in
                            Task { await setFeatured(position: slot.position, photoId: photoId) }
                        },
                        onClear: {
                            Task { await setFeatured(position: slot.position, photoId: nil) }
                        }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadData() async {
        do {
            async let photosTask = APIClient.shared.getMyPhotosForFeaturing()
            myPhotos = (try? await photosTask) ?? []

            if let username = appState.currentUser?.username {
                let fetched = try await APIClient.shared.getFeaturedGrid(username: username)
                slots = (1...9).map { pos in
                    fetched.first(where: { $0.position == pos }) ?? LNFeaturedSlot(position: pos, photo: nil)
                }
            } else {
                slots = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
            }
        } catch {
            print("Error loading featured data:", error)
            slots = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
        }
        isLoading = false
    }

    private func setFeatured(position: Int, photoId: String?) async {
        do {
            try await APIClient.shared.setFeaturedPhoto(position: position, photoId: photoId)
            let newPhoto = photoId != nil ? myPhotos.first(where: { $0.id == photoId }) : nil
            if let idx = slots.firstIndex(where: { $0.position == position }) {
                slots[idx] = LNFeaturedSlot(position: position, photo: newPhoto)
            }
        } catch {
            print("Error setting featured:", error)
        }
        showingPhotoPicker = false
    }
}

struct PhotoPickerView: View {
    let slot: LNFeaturedSlot
    let photos: [Photo]
    var onSelect: (String) -> Void
    var onClear: () -> Void
    @Environment(\.dismiss) var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 2) {
                        if slot.photo != nil {
                            Button {
                                onClear()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("remove from featured")
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(12)
                            }
                            .padding()
                        }

                        if photos.isEmpty {
                            Text("no unlocked photos yet")
                                .foregroundColor(.gray)
                                .padding(.top, 60)
                        } else {
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
                                            onSelect(photo.id)
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("slot \(slot.position)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
