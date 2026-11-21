import Foundation
import Network

struct DiscoveredScanner: Identifiable, Equatable {
    let id: UUID
    let name: String
    let host: String
    let port: Int

    var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }

    static func == (lhs: DiscoveredScanner, rhs: DiscoveredScanner) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class ScannerDiscovery: ObservableObject {
    @Published var scanners: [DiscoveredScanner] = []
    @Published var isSearching = false

    private var browser: NWBrowser?
    private var resolvers: [NWConnection] = []

    func startDiscovery() {
        isSearching = true
        scanners = []

        // Browse for _eSCL._tcp services (AirScan standard)
        let params = NWParameters()
        params.includePeerToPeer = false
        browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_eSCL._tcp", domain: nil), using: params)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .failed:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                for result in results {
                    if case .service(let name, _, _, _) = result.endpoint {
                        self?.resolveService(endpoint: result.endpoint, name: name)
                    }
                }
            }
        }

        browser?.start(queue: .main)
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        resolvers.forEach { $0.cancel() }
        resolvers = []
        isSearching = false
    }

    private func resolveService(endpoint: NWEndpoint, name: String) {
        let conn = NWConnection(to: endpoint, using: .tcp)

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .ready = state {
                    if let innerEndpoint = conn.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = innerEndpoint {
                        let hostStr = "\(host)"
                            .replacingOccurrences(of: "%en0", with: "")
                            .replacingOccurrences(of: "%en1", with: "")
                        let scanner = DiscoveredScanner(
                            id: UUID(),
                            name: name,
                            host: hostStr,
                            port: Int(port.rawValue)
                        )
                        if !(self?.scanners.contains(where: { $0.name == name }) ?? false) {
                            self?.scanners.append(scanner)
                        }
                    }
                    conn.cancel()
                }
            }
        }

        resolvers.append(conn)
        conn.start(queue: .main)
    }

    // Manual IP entry fallback
    func addManualScanner(host: String, port: Int = 80, name: String = "扫描仪") {
        let scanner = DiscoveredScanner(id: UUID(), name: name, host: host, port: port)
        if !scanners.contains(where: { $0.host == host }) {
            scanners.append(scanner)
        }
    }
}
