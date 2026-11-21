import Foundation

enum ESCLError: LocalizedError {
    case httpError(Int)
    case invalidResponse
    case scanJobFailed(String)
    case timeout
    case noData

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "HTTP 错误 \(code)"
        case .invalidResponse: return "扫描仪返回无效响应"
        case .scanJobFailed(let reason): return "扫描任务失败：\(reason)"
        case .timeout: return "扫描仪响应超时"
        case .noData: return "未获取到图片数据"
        }
    }
}

struct ScannerCapabilities {
    let minResolution: Int
    let maxResolution: Int
    let supportedColorModes: [String]
    let supportedFormats: [String]
    let maxWidth: Int  // in 1/300 inches
    let maxHeight: Int
}

actor ESCLClient {
    private let baseURL: URL
    private let session: URLSession

    init(scannerURL: URL) {
        self.baseURL = scannerURL.appendingPathComponent("eSCL")
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Scanner Status

    func fetchCapabilities() async throws -> ScannerCapabilities {
        let url = baseURL.appendingPathComponent("ScannerCapabilities")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESCLError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ESCLError.httpError(httpResponse.statusCode)
        }
        return try parseCapabilities(data: data)
    }

    func checkStatus() async throws -> String {
        let url = baseURL.appendingPathComponent("ScannerStatus")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ESCLError.invalidResponse
        }
        let xml = String(data: data, encoding: .utf8) ?? ""
        // Extract State from XML: <scan:State>Idle</scan:State>
        if let range = xml.range(of: #"<scan:State>(.*?)</scan:State>"#,
                                  options: .regularExpression) {
            let match = String(xml[range])
            return match.replacingOccurrences(of: "<scan:State>", with: "")
                        .replacingOccurrences(of: "</scan:State>", with: "")
        }
        return "Unknown"
    }

    // MARK: - Scanning

    func scan(parameters: ScanParameters) async throws -> Data {
        let jobURL = try await createScanJob(parameters: parameters)
        let imageURL = try await waitForJob(jobURL: jobURL)
        return try await downloadImage(url: imageURL)
    }

    // Step 1: POST ScanSettings → get job location
    private func createScanJob(parameters: ScanParameters) async throws -> URL {
        let url = baseURL.appendingPathComponent("ScanJobs")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters.toESCLXML().data(using: .utf8)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESCLError.invalidResponse
        }
        guard httpResponse.statusCode == 201 else {
            throw ESCLError.httpError(httpResponse.statusCode)
        }
        guard let location = httpResponse.value(forHTTPHeaderField: "Location"),
              let jobURL = URL(string: location) else {
            throw ESCLError.scanJobFailed("没有收到 job location header")
        }
        return jobURL
    }

    // Step 2: Poll job status until ready, return NextDocument URL
    private func waitForJob(jobURL: URL, maxAttempts: Int = 60) async throws -> URL {
        let statusURL = jobURL.appendingPathComponent("ScanImageInfo")

        for attempt in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: attempt == 0 ? 1_000_000_000 : 500_000_000)

            let (data, response) = try await session.data(from: statusURL)
            guard let httpResponse = response as? HTTPURLResponse else { continue }

            switch httpResponse.statusCode {
            case 200:
                // Job done, build download URL
                let downloadURL = jobURL.appendingPathComponent("NextDocument")
                return downloadURL
            case 202:
                // Still scanning, continue polling
                continue
            case 404:
                // Job expired (410-like behavior) - retry the whole scan
                throw ESCLError.httpError(404)
            default:
                throw ESCLError.httpError(httpResponse.statusCode)
            }
        }
        throw ESCLError.timeout
    }

    // Step 3: GET NextDocument → image data
    private func downloadImage(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESCLError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ESCLError.httpError(httpResponse.statusCode)
        }
        guard !data.isEmpty else {
            throw ESCLError.noData
        }
        return data
    }

    // MARK: - XML Parsing (minimal)

    private func parseCapabilities(data: Data) throws -> ScannerCapabilities {
        // Simple regex-based parsing for key values
        let xml = String(data: data, encoding: .utf8) ?? ""

        func extract(_ tag: String) -> String? {
            if let range = xml.range(of: "<\(tag)>(.*?)</\(tag)>",
                                      options: .regularExpression) {
                return String(xml[range])
                    .replacingOccurrences(of: "<\(tag)>", with: "")
                    .replacingOccurrences(of: "</\(tag)>", with: "")
            }
            return nil
        }

        let minRes = Int(extract("scan:MinOpticalResolution") ?? "75") ?? 75
        let maxRes = Int(extract("scan:MaxOpticalResolution") ?? "1200") ?? 1200
        let maxW = Int(extract("scan:MaxWidth") ?? "2550") ?? 2550
        let maxH = Int(extract("scan:MaxHeight") ?? "3507") ?? 3507

        return ScannerCapabilities(
            minResolution: minRes,
            maxResolution: maxRes,
            supportedColorModes: ["RGB24", "Grayscale8", "BlackAndWhite1"],
            supportedFormats: ["image/jpeg", "image/png"],
            maxWidth: maxW,
            maxHeight: maxH
        )
    }
}
