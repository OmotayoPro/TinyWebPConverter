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
        didSet {
            guard oldValue != selectedItemID else { return }
            showSelectedOriginalImmediately()
            schedulePreviewUpdate()
        }
    }
    private(set) var selectedItemIDs: Set<BatchItem.ID> = []
    private var anchorItemID: BatchItem.ID?

    var allSelected: Bool { !queue.isEmpty && queue.allSatisfy { selectedItemIDs.contains($0.id) } }

    func toggleSelectAll() {
        if allSelected {
            selectedItemIDs.removeAll()
        } else {
            selectedItemIDs = Set(queue.map(\.id))
            anchorItemID = queue.last?.id
        }
    }

    private(set) var previewOriginalImage: NSImage?
    private(set) var previewEncodedImage: NSImage?
    private(set) var previewOriginalByteCount: Int?
    private(set) var previewEncodedByteCount: Int?
    private(set) var isGeneratingPreview = false
    private(set) var previewErrorMessage: String?

    // Success state: bumps `confettiBurstID` to fire the confetti and shows the
    // toast for 60s (or until dismissed / the next conversion replaces it).
    private(set) var showSuccessToast = false
    private(set) var confettiBurstID = 0
    private var successOutputURLs: [URL] = []
    private var toastDismissTask: Task<Void, Never>?

    private let fileManager: FileManager
    private var previewTask: Task<Void, Never>?
    private var originalLoadTask: Task<Void, Never>?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var selectedItem: BatchItem? {
        guard let selectedItemID else { return nil }
        return queue.first { $0.id == selectedItemID }
    }

    /// True once every file in the queue has finished (converted or failed) —
    /// the Convert button switches to "Clear Files" in this state.
    var conversionFinished: Bool {
        !queue.isEmpty && queue.allSatisfy { item in
            switch item.status {
            case .done, .failed: true
            case .pending, .converting: false
            }
        }
    }

    func selectItem(_ item: BatchItem, modifiers: NSEvent.ModifierFlags = []) {
        let flags = modifiers.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
                if selectedItemID == item.id {
                    // Move preview to first remaining selected item (queue-ordered)
                    selectedItemID = queue.first(where: { selectedItemIDs.contains($0.id) })?.id
                }
            } else {
                selectedItemIDs.insert(item.id)
                selectedItemID = item.id
                anchorItemID = item.id
            }
        } else if flags.contains(.shift),
                  let anchor = anchorItemID,
                  let anchorIdx = queue.firstIndex(where: { $0.id == anchor }),
                  let clickedIdx = queue.firstIndex(where: { $0.id == item.id }) {
            let lo = min(anchorIdx, clickedIdx)
            let hi = max(anchorIdx, clickedIdx)
            selectedItemIDs = Set(queue[lo...hi].map(\.id))
            selectedItemID = item.id
        } else {
            selectedItemIDs = [item.id]
            selectedItemID = item.id
            anchorItemID = item.id
        }
    }

    func removeSelectedItems() {
        guard !selectedItemIDs.isEmpty else { return }
        let firstIdx = queue.firstIndex(where: { selectedItemIDs.contains($0.id) })
        queue.removeAll { selectedItemIDs.contains($0.id) }
        selectedItemIDs.removeAll()
        anchorItemID = nil
        if let idx = firstIdx, !queue.isEmpty {
            let item = queue[min(idx, queue.count - 1)]
            selectedItemID = item.id
            selectedItemIDs = [item.id]
            anchorItemID = item.id
        } else {
            selectedItemID = nil
        }
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
            selectItem(first)  // no modifiers → single-select
        }
    }

    func removeItem(_ item: BatchItem) {
        queue.removeAll { $0.id == item.id }
        selectedItemIDs.remove(item.id)
        if item.id == anchorItemID { anchorItemID = nil }
        guard selectedItemID == item.id else { return }
        selectedItemID = queue.first?.id
        if let id = selectedItemID {
            selectedItemIDs = [id]
            anchorItemID = id
        }
    }

    func clearQueue() {
        queue.removeAll()
        selectedItemID = nil
        selectedItemIDs.removeAll()
        anchorItemID = nil
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
            ) { [weak self] sourceURL, status in
                Task { @MainActor in
                    self?.applyStatus(sourceURL: sourceURL, status: status)
                }
            }
            for result in results {
                applyStatus(sourceURL: result.sourceURL, status: result.status)
            }

            let convertedURLs = results.compactMap { item -> URL? in
                if case .done(let result) = item.status { return result.outputURL }
                return nil
            }
            if !convertedURLs.isEmpty {
                celebrateSuccess(outputURLs: convertedURLs)
            }
        } catch {
            // Batch-level errors (e.g. cap exceeded) are enforced at add time.
        }
    }

    private func celebrateSuccess(outputURLs: [URL]) {
        successOutputURLs = outputURLs
        confettiBurstID += 1
        showSuccessToast = true

        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            self?.showSuccessToast = false
        }
    }

    func dismissSuccessToast() {
        toastDismissTask?.cancel()
        showSuccessToast = false
    }

    /// Opens Finder with the converted files selected.
    func revealConvertedFiles() {
        guard !successOutputURLs.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(successOutputURLs)
    }

    // Queue items are unique by sourceURL (enforced in addFiles), so it's a safe
    // key for matching the converter's progress reports back to the sidebar.
    private func applyStatus(sourceURL: URL, status: BatchItemStatus) {
        guard let index = queue.firstIndex(where: { $0.sourceURL == sourceURL }) else { return }
        queue[index].status = status
    }

    /// Swaps the preview to the newly selected image right away, so the encode
    /// shimmer plays over the new image instead of the previously displayed one.
    private func showSelectedOriginalImmediately() {
        originalLoadTask?.cancel()
        previewEncodedImage = nil
        previewEncodedByteCount = nil
        previewErrorMessage = nil

        guard let url = selectedItem?.sourceURL else {
            previewOriginalImage = nil
            previewOriginalByteCount = nil
            return
        }

        originalLoadTask = Task { [weak self] in
            let (data, byteCount): (Data?, Int?) = await Task.detached(priority: .userInitiated) {
                let data = try? Data(contentsOf: url)
                let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
                return (data, bytes)
            }.value
            guard let self, !Task.isCancelled, self.selectedItem?.sourceURL == url else { return }
            if let data { self.previewOriginalImage = NSImage(data: data) }
            self.previewOriginalByteCount = byteCount
        }
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
