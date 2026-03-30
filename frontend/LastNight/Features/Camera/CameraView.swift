import SwiftUI
import AVFoundation

struct CameraView: View {
    let groupId: String
    var onPhotoTaken: (Photo) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var isUploading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Button("cancel") { dismiss() }
                        .foregroundColor(.white)
                        .padding()
                    Spacer()
                }

                Spacer()

                Text("camera coming soon")
                    .foregroundColor(.gray)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
