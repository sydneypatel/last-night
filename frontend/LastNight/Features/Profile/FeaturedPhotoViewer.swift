import SwiftUI

struct FeaturedPhotoViewer: View {
    let photos: [FeaturedPhoto]
    let startIndex: Int
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0

    init(photos: [FeaturedPhoto], startIndex: Int) {
        self.photos = photos
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    SwiftUI.Group {
                        if let url = photo.url, let imageURL = URL(string: url) {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                ProgressView().tint(.white)
                            }
                        } else {
                            Color.white.opacity(0.05)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only track downward drags
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 120 {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("\(currentIndex + 1) of \(photos.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                }
                .padding()
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    // Background fades slightly as you drag down, signaling dismissal.
    private var backgroundOpacity: Double {
        let progress = min(dragOffset / 400, 1)
        return 1 - (progress * 0.4)
    }
}
