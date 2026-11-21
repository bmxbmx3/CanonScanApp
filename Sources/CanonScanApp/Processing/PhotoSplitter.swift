import Foundation
import Vision
import UIKit
import CoreImage

struct SplitResult {
    let image: UIImage
    let boundingBox: CGRect  // normalized coordinates
}

class PhotoSplitter {

    // Split multiple photos from a full-flatbed scan.
    // The flatbed scan is typically A4/letter with multiple photos placed on glass.
    // We detect rectangular regions that differ from the background (white/gray).
    func splitPhotos(from imageData: Data) async throws -> [UIImage] {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            return [UIImage(data: imageData)].compactMap { $0 }
        }

        let results = try await detectRectangles(in: cgImage)

        if results.isEmpty {
            // No rectangles found — return the whole image as-is
            return [uiImage]
        }

        return results.compactMap { result in
            cropImage(cgImage: cgImage, normalizedRect: result.boundingBox, originalSize: uiImage.size)
        }
    }

    // MARK: - Rectangle Detection (Vision framework)

    private func detectRectangles(in cgImage: CGImage) async throws -> [VNRectangleObservation] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3   // allow portraits and landscapes
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.1          // at least 10% of image area
        request.maximumObservations = 16   // up to 16 photos per flatbed
        request.minimumConfidence = 0.6

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNRectangleObservation] else {
            return []
        }

        // Filter out the flatbed boundary itself (nearly full-image rectangles)
        return observations.filter { obs in
            let area = obs.boundingBox.width * obs.boundingBox.height
            return area < 0.95  // skip rects that cover >95% of image
        }
    }

    // MARK: - Cropping

    private func cropImage(cgImage: CGImage, normalizedRect: CGRect, originalSize: CGSize) -> UIImage? {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Vision uses bottom-left origin; UIKit uses top-left — flip Y
        let flippedOriginY = 1.0 - normalizedRect.origin.y - normalizedRect.height

        let cropRect = CGRect(
            x: normalizedRect.origin.x * imageWidth,
            y: flippedOriginY * imageHeight,
            width: normalizedRect.width * imageWidth,
            height: normalizedRect.height * imageHeight
        ).integral

        // Add a small padding
        let padding: CGFloat = 10
        let paddedRect = cropRect.insetBy(dx: -padding, dy: -padding)
            .intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        guard let croppedCG = cgImage.cropping(to: paddedRect) else { return nil }

        // Auto-rotate based on content if needed
        let result = UIImage(cgImage: croppedCG)
        return result
    }

    // MARK: - Single photo enhancement (optional)

    func enhance(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()

        // Auto levels: adjust exposure and saturation slightly
        let filter = CIFilter(name: "CIVibrance")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0.2, forKey: "inputAmount")

        guard let output = filter.outputImage,
              let result = context.createCGImage(output, from: output.extent) else {
            return image
        }
        return UIImage(cgImage: result, scale: image.scale, orientation: image.imageOrientation)
    }
}
