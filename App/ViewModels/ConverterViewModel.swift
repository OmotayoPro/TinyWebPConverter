import Foundation
import Observation
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

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// PRD §6.1: sniffs each file's real format and rejects anything outside the curated list,
    /// reporting "File not added" with a reason rather than failing silently.
    func addFiles(_ urls: [URL]) {
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
    }

    func removeItem(_ item: BatchItem) {
        queue.removeAll { $0.id == item.id }
    }

    func clearQueue() {
        queue.removeAll()
    }

    func dismissRejectedFile(_ file: RejectedFile) {
        rejectedFiles.removeAll { $0.id == file.id }
    }

    /// Converts every queued file with default settings, each to its own source folder
    /// (PRD §6.2 default). The settings controls panel lands in a follow-up PR.
    func convertAll() async {
        guard !queue.isEmpty, !isConverting else { return }
        isConverting = true
        defer { isConverting = false }

        let urls = queue.map(\.sourceURL)

        do {
            let results = try await BatchConverter.convert(
                sourceURLs: urls,
                settings: ConversionSettings(),
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
}
