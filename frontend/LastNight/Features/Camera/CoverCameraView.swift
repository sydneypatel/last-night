import SwiftUI
import AVFoundation

struct CoverCameraView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CameraViewModel()
    var onCapture: (UIImage) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        viewModel.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("COVER PHOTO")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Button {
                        viewModel.flipCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                Button {
                    viewModel.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 76, height: 76)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 62, height: 62)
                    }
                }
                .disabled(viewModel.isCapturing)
                .padding(.bottom, 48)
            }

            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }
        }
        .onChange(of: viewModel.capturedImage) { _, newImage in
            guard let newImage else { return }
            viewModel.stopSession()
            onCapture(newImage)
            dismiss()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}
