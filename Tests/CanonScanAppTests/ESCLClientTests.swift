import XCTest
@testable import CanonScanApp

final class ESCLClientTests: XCTestCase {

    // MARK: - ScanParameters XML generation

    func testScanParametersXMLContainsResolution() {
        let params = ScanParameters(resolution: .dpi600, colorMode: .color, outputFormat: .png, autoSplit: false)
        let xml = params.toESCLXML()
        XCTAssertTrue(xml.contains("<scan:XResolution>600</scan:XResolution>"))
        XCTAssertTrue(xml.contains("<scan:YResolution>600</scan:YResolution>"))
    }

    func testScanParametersXMLContainsColorMode() {
        let params = ScanParameters(resolution: .dpi300, colorMode: .grayscale, outputFormat: .jpeg, autoSplit: false)
        let xml = params.toESCLXML()
        XCTAssertTrue(xml.contains("<scan:ColorMode>Grayscale8</scan:ColorMode>"))
    }

    func testScanParametersXMLContainsFormat() {
        let params = ScanParameters(resolution: .dpi300, colorMode: .color, outputFormat: .jpeg, autoSplit: false)
        let xml = params.toESCLXML()
        XCTAssertTrue(xml.contains("<pwg:DocumentFormat>image/jpeg</pwg:DocumentFormat>"))
    }

    func testScanParametersXMLIsValidXML() {
        let params = ScanParameters()
        let xml = params.toESCLXML()
        // Check XML declaration and root element
        XCTAssertTrue(xml.hasPrefix("<?xml version=\"1.0\""))
        XCTAssertTrue(xml.contains("<scan:ScanSettings"))
        XCTAssertTrue(xml.contains("</scan:ScanSettings>"))
    }

    func testAllResolutionsGenerateValidXML() {
        for resolution in Resolution.allCases {
            var params = ScanParameters()
            params.resolution = resolution
            let xml = params.toESCLXML()
            XCTAssertTrue(xml.contains("<scan:XResolution>\(resolution.rawValue)</scan:XResolution>"),
                         "Resolution \(resolution.rawValue) not found in XML")
        }
    }

    func testAllColorModesGenerateValidXML() {
        for mode in ColorMode.allCases {
            var params = ScanParameters()
            params.colorMode = mode
            let xml = params.toESCLXML()
            XCTAssertTrue(xml.contains("<scan:ColorMode>\(mode.rawValue)</scan:ColorMode>"),
                         "ColorMode \(mode.rawValue) not found in XML")
        }
    }

    // MARK: - Resolution enum

    func testResolutionDisplayNames() {
        XCTAssertEqual(Resolution.dpi300.displayName, "300 DPI")
        XCTAssertEqual(Resolution.dpi600.displayName, "600 DPI")
        XCTAssertEqual(Resolution.dpi1200.displayName, "1200 DPI")
    }

    func testColorModeDisplayNames() {
        XCTAssertEqual(ColorMode.color.displayName, "彩色")
        XCTAssertEqual(ColorMode.grayscale.displayName, "灰度")
        XCTAssertEqual(ColorMode.blackAndWhite.displayName, "黑白")
    }

    func testOutputFormatFileExtensions() {
        XCTAssertEqual(OutputFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(OutputFormat.png.fileExtension, "png")
    }
}
