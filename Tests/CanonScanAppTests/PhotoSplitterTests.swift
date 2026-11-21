import XCTest
import UIKit
@testable import CanonScanApp

final class PhotoSplitterTests: XCTestCase {
    private let splitter = PhotoSplitter()

    // MARK: - Single photo (no split needed)

    func testSinglePhotoReturnedWhenNoRectanglesDetected() async throws {
        // Create a plain white image (simulates empty flatbed)
        let image = makeImage(color: .white, size: CGSize(width: 400, height: 600))
        let data = image.pngData()!

        let results = try await splitter.splitPhotos(from: data)
        // White image has no detectable rectangles → returns original
        XCTAssertEqual(results.count, 1)
    }

    func testInvalidDataReturnsEmpty() async throws {
        let invalidData = Data("not an image".utf8)
        let results = try await splitter.splitPhotos(from: invalidData)
        XCTAssertTrue(results.isEmpty)
    }

    func testValidImageDataReturnsAtLeastOne() async throws {
        let image = makeImage(color: .lightGray, size: CGSize(width: 800, height: 1100))
        let data = image.jpegData(compressionQuality: 0.9)!
        let results = try await splitter.splitPhotos(from: data)
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    // MARK: - Enhance

    func testEnhanceReturnsNonNilImage() {
        let image = makeImage(color: .blue, size: CGSize(width: 200, height: 200))
        let enhanced = splitter.enhance(image)
        XCTAssertNotNil(enhanced)
    }

    // MARK: - Helpers

    private func makeImage(color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}
