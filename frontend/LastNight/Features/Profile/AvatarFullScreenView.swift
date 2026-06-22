import SwiftUI

/// Avatar viewer: centered circle on a dark backdrop.
/// Tap anywhere or swipe down to dismiss.
struct AvatarFullScreenView: View {
    let avatarUrl: String?
    let fallbackInitial: String
    @Environment(\.dismiss) var dismiss
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()

            SwiftUI.Group {
                if let avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        placeholderFill
                    }
                } else {
                    placeholderFill
                }
            }
            .frame(width: 320, height: 320)
            .clipShape(Circle())
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
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
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismiss()
        }
        .preferredColorScheme(.dark)
    }

    private var placeholderFill: some View {
        Color.white.opacity(0.1)
            .overlay(
                Text(fallbackInitial)
                    .font(.system(size: 96))
                    .foregroundColor(.white)
            )
    }

    private var backgroundOpacity: Double {
        let progress = min(dragOffset / 400, 1)
        return 1 - (progress * 0.4)
    }
}
