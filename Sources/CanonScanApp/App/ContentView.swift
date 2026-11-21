import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var discovery = ScannerDiscovery()
    @State private var selectedScanner: DiscoveredScanner?
    @State private var parameters = ScanParameters()
    @State private var scannedImages: [UIImage] = []
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var showingManualIP = false
    @State private var manualIP = ""
    @State private var showingSaveConfirm = false

    private let splitter = PhotoSplitter()

    var body: some View {
        NavigationSplitView {
            scannerListView
        } detail: {
            mainView
        }
    }

    // MARK: - Scanner List (sidebar)

    private var scannerListView: some View {
        List(selection: $selectedScanner) {
            Section("发现的扫描仪") {
                if discovery.scanners.isEmpty {
                    if discovery.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("搜索中…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("未找到扫描仪")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(discovery.scanners) { scanner in
                        Label(scanner.name, systemImage: "printer")
                            .tag(scanner)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("CanonScan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    discovery.startDiscovery()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem {
                Button("手动输入 IP") {
                    showingManualIP = true
                }
            }
        }
        .sheet(isPresented: $showingManualIP) {
            manualIPSheet
        }
        .onAppear {
            discovery.startDiscovery()
        }
    }

    // MARK: - Main scanning area

    private var mainView: some View {
        VStack(spacing: 0) {
            if let scanner = selectedScanner {
                // Settings bar
                settingsBar
                    .padding()
                    .background(.bar)

                Divider()

                // Results grid
                if scannedImages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "scanner")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                        Text(isScanning ? "扫描中…" : "点击扫描开始")
                            .foregroundStyle(.secondary)
                        if isScanning {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                            ForEach(Array(scannedImages.enumerated()), id: \.offset) { idx, img in
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(8)
                                    .shadow(radius: 4)
                                    .contextMenu {
                                        Button("保存到相册") { saveToPhotos(img) }
                                        Button("删除", role: .destructive) {
                                            scannedImages.remove(at: idx)
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }

                // Error display
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                        Spacer()
                        Button("关闭") { errorMessage = nil }
                    }
                    .padding()
                    .background(.red.opacity(0.1))
                }

                Divider()

                // Bottom action bar
                HStack {
                    Button(action: startScan) {
                        Label(isScanning ? "扫描中…" : "开始扫描",
                              systemImage: isScanning ? "hourglass" : "scanner")
                            .frame(minWidth: 160)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning)

                    if !scannedImages.isEmpty {
                        Button("全部保存到相册") {
                            scannedImages.forEach { saveToPhotos($0) }
                            showingSaveConfirm = true
                        }
                        .buttonStyle(.bordered)

                        Button("清空", role: .destructive) {
                            scannedImages = []
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()

            } else {
                ContentUnavailableView(
                    "选择扫描仪",
                    systemImage: "scanner",
                    description: Text("从左侧列表选择已发现的扫描仪，或手动输入 IP 地址")
                )
            }
        }
        .navigationTitle(selectedScanner?.name ?? "扫描")
        .alert("保存成功", isPresented: $showingSaveConfirm) {
            Button("好") {}
        } message: {
            Text("已保存 \(scannedImages.count) 张照片到相册")
        }
    }

    // MARK: - Settings bar

    private var settingsBar: some View {
        HStack(spacing: 20) {
            // Resolution
            VStack(alignment: .leading, spacing: 2) {
                Text("分辨率").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $parameters.resolution) {
                    ForEach(Resolution.allCases) { res in
                        Text(res.displayName).tag(res)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }

            // Color mode
            VStack(alignment: .leading, spacing: 2) {
                Text("颜色").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $parameters.colorMode) {
                    ForEach(ColorMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            // Format
            VStack(alignment: .leading, spacing: 2) {
                Text("格式").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $parameters.outputFormat) {
                    ForEach(OutputFormat.allCases) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            // Auto split
            VStack(alignment: .leading, spacing: 2) {
                Text("多张分割").font(.caption).foregroundStyle(.secondary)
                Toggle("", isOn: $parameters.autoSplit)
                    .labelsHidden()
            }

            Spacer()
        }
    }

    // MARK: - Manual IP sheet

    private var manualIPSheet: some View {
        NavigationStack {
            Form {
                Section("扫描仪 IP 地址") {
                    TextField("例：192.168.1.100", text: $manualIP)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Text("在打印机屏幕上找「网络信息」，查看 IP 地址")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .navigationTitle("手动输入 IP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showingManualIP = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        discovery.addManualScanner(host: manualIP)
                        showingManualIP = false
                        manualIP = ""
                    }
                    .disabled(manualIP.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func startScan() {
        guard let scanner = selectedScanner else { return }
        isScanning = true
        errorMessage = nil

        Task {
            do {
                let client = ESCLClient(scannerURL: scanner.baseURL)
                let imageData = try await client.scan(parameters: parameters)

                let images: [UIImage]
                if parameters.autoSplit {
                    images = try await splitter.splitPhotos(from: imageData)
                } else {
                    images = [UIImage(data: imageData)].compactMap { $0 }
                }

                await MainActor.run {
                    scannedImages.append(contentsOf: images)
                    isScanning = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isScanning = false
                }
            }
        }
    }

    private func saveToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}

#Preview {
    ContentView()
}
