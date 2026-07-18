import Foundation
import Observation
import AppKit
import TinyWebPCore

enum ViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
}

@MainActor
@Observable
final class ConverterViewModel {
    struct RejectedFile: Identifiable {
        let id = UUID()
        let fileName: String
        let reason: String
    }

    private(set) var queue: [BatchItem] = []
    private(set) var rejectedFiles: [RejectedFile] = []
    private(set) var isConverting = false

    var isSidebarCollapsed = false
    var viewMode: ViewMode = .grid

    /// PRD §6.2: resets to defaults every launch — nothing here is persisted.
    var settings = ConversionSettings() {
        didSet { schedulePreviewUpdate() }
    }
    /// `nil` means "same folder as source" (PRD §6.2 default).
    var outputDirectoryOverride: URL?

    var selectedItemID: BatchItem.ID? {
        didSet { schedulePreviewUpdate() }
    }

    private(set) var previewOriginalImage: NSImage?
    private(set) var previewEncodedImage: NSImage?
    private(set) var previewOriginalByteCount: Int?
    private(set) var previewEncodedByteCount: Int?
    private(set) var isGeneratingPreview = false
    private(set) var previewErrorMessage: String?

    private let fileManager: FileManager
    private var previewTask: Task<Void, Never>?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var selectedItem: BatchItem? {
        guard let selectedItemID else { return nil }
        return queue.first { $0.id == selectedItemID }
    }

    func selectItem(_ item: BatchItem) {
        selectedItemID = item.id
    }

    /// PRD §6.1: sniffs each file's real format and rejects anything outside the curated list.
    func addFiles(_ urls: [URL]) {
        let hadNoSelection = selectedItemID == nil

        for url in urls {
            guard queue.count < BatchConverter.maxBatchSize else {
                rejectedFiles.append(RejectedFile(
                    fileName: url.lastPathComponent,
                    reason: "Batch limit reached (\(BatchConverter.maxBatchSize) images)"
                ))
                continue
            }
            guard !queue.contains(where: { $0.sourceURL == url }) else { continue }

            switch FileValidator.validate(url: url) {
            case .success:
                queue.append(BatchItem(sourceURL: url))
            case .failure(let error):
                rejectedFiles.append(RejectedFile(
                    fileName: url.lastPathComponent,
                    reason: error.errorDescription ?? "This file format isn't supported"
                ))
            }
        }

        if hadNoSelection, let first = queue.first {
            selectItem(first)
        }
    }

    func removeItem(_ item: BatchItem) {
        queue.removeAll { $0.id == item.id }
        guard selectedItemID == item.id else { return }
        selectedItemID = queue.first?.id
    }

    func clearQueue() {
        queue.removeAll()
        selectedItemID = nil
        previewTask?.cancel()
        previewOriginalImage = nil
        previewEncodedImage = nil
        previewOriginalByteCount = nil
        previewEncodedByteCount = nil
        previewErrorMessage = nil
    }

    func dismissRejectedFile(_ file: RejectedFile) {
        rejectedFiles.removeAll { $0.id == file.id }
    }

    func convertAll() async {
        guard !queue.isEmpty, !isConverting else { return }
        isConverting = true
        defer { isConverting = false }

        do {
            let results = try await BatchConverter.convert(
                sourceURLs: queue.map(\.sourceURL),
                settings: settings,
                outputDirectory: outputDirectoryOverride,
                fileManager: fileManager
            ) { [weak self] id, status in
                Task { @MainActor in
                    self?.applyStatus(id: id, status: status)
                }
            }
            for result in results {
                applyStatus(id: result.id, status: result.status)
            }
        } catch {
            // Batch-level errors (e.g. cap exceeded) are enforced at add time.
        }
    }

    private func applyStatus(id: UUID, status: BatchItemStatus) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[index].status = status
    }

    /// PRD §6.3: debounced — only re-encodes after the user pauses adjusting settings.
    private func schedulePreviewUpdate() {
        previewTask?.cancel()

        guard let item = selectedItem else {
            previewOriginalImage = nil
            previewEncodedImage = nil
            previewOriginalByteCount = nil
            previewEncodedByteCount = nil
            previewErrorMessage = nil
            return
        }

        let url = item.sourceURL
        let currentSettings = settings
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.generatePreview(for: url, settings: currentSettings)
        }
    }

    private func generatePreview(for url: URL, settings: ConversionSettings) async {
        isGeneratingPreview = true
        previewErrorMessage = nil
        defer { isGeneratingPreview = false }

        do {
            // Run the CPU-intensive encode off the main actor so the UI stays responsive.
            let (encodedData, originalData, originalByteCount): (Data, Data?, Int?) =
                try await Task.detached(priority: .userInitiated) {
                    let encoded = try ConversionPipeline.encodePreview(fileAt: url, settings: settings)
                    let original = try? Data(contentsOf: url)
                    let byteCount = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
                    return (encoded, original, byteCount)
                }.value

            guard !Task.isCancelled else { return }
            previewEncodedByteCount = encodedData.count
            previewEncodedImage = NSImage(data: encodedData)
            if let originalData { previewOriginalImage = NSImage(data: originalData) }
            previewOriginalByteCount = originalByteCount
        } catch {
            guard !Task.isCancelled else { return }
            previewErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't generate a preview."
            previewEncodedImage = nil
            previewEncodedByteCount = nil
        }
    }
}
