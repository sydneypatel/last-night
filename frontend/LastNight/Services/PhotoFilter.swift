//
//  PhotoFilter.swift
//  LastNight
//
//  Created by Sydney Patel on 3/31/26.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct PhotoFilter {
    static let context = CIContext()

    /// Applies a digital camera / disposable camera look:
    /// slight warmth, boosted contrast, subtle grain, lifted blacks
    static func applyDigiCamFilter(to image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        var ciImage = CIImage(cgImage: cgImage)

        // 1. Color controls — warm, slightly contrasty, lifted shadows
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = 1.15
        colorControls.brightness = 0.02
        colorControls.contrast = 1.08
        guard let colorResult = colorControls.outputImage else { return image }
        ciImage = colorResult

        // 2. Color matrix — add warmth (push reds/greens slightly)
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = ciImage
        colorMatrix.rVector = CIVector(x: 1.08, y: 0, z: 0, w: 0)
        colorMatrix.gVector = CIVector(x: 0, y: 1.02, z: 0, w: 0)
        colorMatrix.bVector = CIVector(x: 0, y: 0, z: 0.92, w: 0)
        colorMatrix.biasVector = CIVector(x: 0.02, y: 0.01, z: 0, w: 0)
        guard let matrixResult = colorMatrix.outputImage else { return image }
        ciImage = matrixResult

        // 3. Vignette — subtle dark edges
        let vignette = CIFilter.vignette()
        vignette.inputImage = ciImage
        vignette.intensity = 0.4
        vignette.radius = 1.2
        guard let vignetteResult = vignette.outputImage else { return image }
        ciImage = vignetteResult

        // 4. Noise reduction — slightly soften like a cheap sensor
        let noiseReduction = CIFilter.noiseReduction()
        noiseReduction.inputImage = ciImage
        noiseReduction.noiseLevel = 0.015
        noiseReduction.sharpness = 0.4
        guard let noiseResult = noiseReduction.outputImage else { return image }
        ciImage = noiseResult

        // Render
        guard let output = context.createCGImage(ciImage, from: ciImage.extent) else { return image }
        return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation)
    }

    static func toJPEGData(_ image: UIImage, quality: CGFloat = 0.85) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

    /// Create a blurred thumbnail for the locked placeholder
    static func makeBlurredThumbnail(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        var ciImage = CIImage(cgImage: cgImage)

        // Downscale to thumbnail size
        let scale = 200.0 / max(ciImage.extent.width, ciImage.extent.height)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Heavy blur
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = scaled
        blur.radius = 20
        guard let blurred = blur.outputImage else { return image }

        guard let output = context.createCGImage(blurred, from: scaled.extent) else { return image }
        return UIImage(cgImage: output)
    }
}
