import SwiftUI

/// Reusable circular crop editor. Pinch to zoom, drag to reposition.
/// Renders the visible region of the circular mask to a square UIImage.
struct AvatarCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onCrop: (UIImage) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropDiameter: CGFloat = 300
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                ZStack {
                    // The image, zoomed + panned
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropDiameter, height: cropDiameter)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: cropDiameter, height: cropDiameter)
                        .clipShape(Circle())

                    // Dim mask outside the circle
                    CropMask(diameter: cropDiameter)
                        .allowsHitTesting(false)
                }
                .frame(width: cropDiameter, height: cropDiameter)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, minScale), maxScale)
                            }
                            .onEnded { _ in
                                lastScale = scale
                                clampOffset()
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                clampOffset()
                                lastOffset = offset
                            }
                    )
                )

                Text("pinch to zoom · drag to reposition")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 24)

                Spacer()

                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Text("cancel")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }

                    Button {
                        if let cropped = renderCrop() {
                            onCrop(cropped)
                        }
                    } label: {
                        Text("use photo")
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    // Keep the image covering the crop circle (no empty gaps).
    private func clampOffset() {
        let scaledSize = cropDiameter * scale
        let maxOffset = max(0, (scaledSize - cropDiameter) / 2)
        var newOffset = offset
        newOffset.width = min(max(offset.width, -maxOffset), maxOffset)
        newOffset.height = min(max(offset.height, -maxOffset), maxOffset)
        withAnimation(.interactiveSpring()) {
            offset = newOffset
        }
        lastOffset = newOffset
    }

    // Render the displayed crop region to a square UIImage.
    @MainActor
    private func renderCrop() -> UIImage? {
        let content = Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: cropDiameter, height: cropDiameter)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: cropDiameter, height: cropDiameter)
            .clipped()

        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

private struct CropMask: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.8), lineWidth: 2)
            .frame(width: diameter, height: diameter)
    }
}
