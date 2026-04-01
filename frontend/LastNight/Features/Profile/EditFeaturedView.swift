import SwiftUI

struct EditFeaturedView: View {
    @Environment(\.dismiss) var dismiss
    @State private var slots: [LNFeaturedSlot] = []
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
                        // Instructions
                        Text("tap a slot to add or change a photo")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)

                        // 3x3 grid
                        FeaturedGridView(slots: slots, isOwner: true) { slot in
                            selectedSlot = slot
                            showingPhotoPicker = true
                        }
                        .padding(.horizontal, 1)
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
        async let gridTask = APIClient.shared.getFeaturedGrid(username: "me_placeholder")
        async let photosTask = APIClient.shared.getMyPhotosForFeaturing()

        // Load my featured grid
        do {
            myPhotos = try await photosTask
        } catch {
            print("Error loading photos:", error)
        }

        // Build empty grid if needed
        if slots.isEmpty {
            slots = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
        }

        isLoading = false
    }

    private func setFeatured(position: Int, photoId: String?) async {
        do {
            try await APIClient.shared.setFeaturedPhoto(position: position, photoId: photoId)
            // Update local state
            if let idx = slots.firstIndex(where: { $0.position == position }) {
                let newPhoto = photoId != nil ? myPhotos.first(where: { $0.id == photoId }) : nil
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
