import Foundation
import Observation
import AppKit
import TinyWebPCore

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

    /// PRD §6.2: resets to defaults every launch - nothing here is persisted.
    var settings = ConversionSettings() {
        didSet { schedulePreviewUpdate() }
    }
    /// `nil` means "same folder as source" (PRD §6.2 default); set to override for the whole batch.
    var outputDirectoryOverride: URL?

    var selectedItemID: BatchItem.ID? {
        didSet { schedulePreviewUpdate() }
    }
    /// 0 shows only the original, 1 shows only the WebP-encoded preview.
    var previewRevealAmount: Double = 0.5

    private(set) var previewOriginalImage: NSImage?
    private(set) var previewWebPImage: NSImage?
    private(set) var previewOriginalByteCount: Int?
    private(set) var previewWebPByteCount: Int?
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

    /// PRD §6.1: sniffs each file's real format and rejects anything outside the curated list,
    /// reporting "File not added" with a reason rather than failing silently.
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
    }

    func dismissRejectedFile(_ file: RejectedFile) {
        rejectedFiles.removeAll { $0.id == file.id }
    }

    /// Converts every queued file with the current settings (PRD §6.3 reuses this same encode
    /// step for the live preview, targeting memory instead of disk).
    func convertAll() async {
        guard !queue.isEmpty, !isConverting else { return }
        isConverting = true
        defer { isConverting = false }

        let urls = queue.map(\.sourceURL)

        do {
            let results = try await BatchConverter.convert(
                sourceURLs: urls,
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
            // Batch-level failure (currently only the 50-image cap, already enforced at add
            // time) - nothing per-item to update.
        }
    }

    private func applyStatus(id: UUID, status: BatchItemStatus) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[index].status = status
    }

    /// PRD §6.3: preview updates are debounced - only re-encode once the user pauses adjusting
    /// settings, not on every slider tick.
    private func schedulePreviewUpdate() {
        previewTask?.cancel()

        guard let item = selectedItem else {
            previewOriginalImage = nil
            previewWebPImage = nil
            previewOriginalByteCount = nil
            previewWebPByteCount = nil
            previewErrorMessage = nil
            return
        }

        let url = item.sourceURL
        let currentSettings = settings
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.generatePreview(for: url, settings: currentSettings)
        }
    }

    private func generatePreview(for url: URL, settings: ConversionSettings) async {
        isGeneratingPreview = true
        previewErrorMessage = nil
        defer { isGeneratingPreview = false }

        do {
            let data = try ConversionPipeline.encodePreview(fileAt: url, settings: settings)
            guard !Task.isCancelled else { return }
            previewWebPByteCount = data.count
            previewWebPImage = NSImage(data: data)
            previewOriginalImage = NSImage(contentsOf: url)
            previewOriginalByteCount = (try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int
        } catch {
            guard !Task.isCancelled else { return }
            previewErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't generate a preview."
            previewWebPImage = nil
            previewWebPByteCount = nil
        }
    }
}
