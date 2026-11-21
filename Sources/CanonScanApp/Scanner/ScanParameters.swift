import Foundation

enum ColorMode: String, CaseIterable, Identifiable {
    case color = "RGB24"
    case grayscale = "Grayscale8"
    case blackAndWhite = "BlackAndWhite1"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .color: return "彩色"
        case .grayscale: return "灰度"
        case .blackAndWhite: return "黑白"
        }
    }
}

enum Resolution: Int, CaseIterable, Identifiable {
    case dpi150 = 150
    case dpi300 = 300
    case dpi600 = 600
    case dpi1200 = 1200

    var id: Int { rawValue }
    var displayName: String { "\(rawValue) DPI" }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case jpeg = "image/jpeg"
    case png = "image/png"

    var id: String { rawValue }
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        }
    }
    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG（无损）"
        }
    }
}

struct ScanParameters {
    var resolution: Resolution = .dpi600
    var colorMode: ColorMode = .color
    var outputFormat: OutputFormat = .png
    var autoSplit: Bool = true  // 多张照片自动分割

    // eSCL XML for ScanSettings
    func toESCLXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <scan:ScanSettings xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03"
                          xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
          <pwg:Version>2.63</pwg:Version>
          <scan:Intent>Photo</scan:Intent>
          <pwg:ScanRegions>
            <pwg:ScanRegion>
              <pwg:ContentRegionUnits>escl:ThreeHundredthsOfInches</pwg:ContentRegionUnits>
              <pwg:Height>3300</pwg:Height>
              <pwg:Width>2550</pwg:Width>
              <pwg:XOffset>0</pwg:XOffset>
              <pwg:YOffset>0</pwg:YOffset>
            </pwg:ScanRegion>
          </pwg:ScanRegions>
          <pwg:InputSource>Platen</pwg:InputSource>
          <scan:ColorMode>\(colorMode.rawValue)</scan:ColorMode>
          <scan:XResolution>\(resolution.rawValue)</scan:XResolution>
          <scan:YResolution>\(resolution.rawValue)</scan:YResolution>
          <pwg:DocumentFormat>\(outputFormat.rawValue)</pwg:DocumentFormat>
        </scan:ScanSettings>
        """
    }
}
