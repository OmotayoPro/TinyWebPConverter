import Foundation

public struct BatchItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let sourceURL: URL
    public var status: BatchItemStatus

    public init(id: UUID = UUID(), sourceURL: URL, status: BatchItemStatus = .pending) {
        self.id = id
        self.sourceURL = sourceURL
        self.status = status
    }
}

public enum BatchItemStatus: Sendable, Equatable {
    case pending
    case converting
    case done(ConversionResult)
    case failed(ConversionError)
}

public enum BatchConversionError: Error, LocalizedError, Sendable, Equatable {
    case batchTooLarge(count: Int, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .batchTooLarge(let count, let limit):
            return "This batch has \(count) images, which is over the \(limit)-image limit."
        }
    }
}

/// PRD §6.4: up to 50 images per batch, converted in parallel under a concurrency cap so the
/// app doesn't try to decode all of them at once and exhaust memory. One failed image doesn't
/// stop the rest of the batch — failures are reported per item, not thrown.
public enum BatchConverter {
    public static let maxBatchSize = 50
    public static let defaultConcurrencyLimit = 4

    /// - Parameter outputDirectory: Where converted files go. `nil` (the default) matches
    ///   PRD §6.2's default of "same folder as source" — each item writes next to its own
    ///   source file. Pass a concrete URL to route the whole batch to one folder instead
    ///   (e.g. a user-picked output location).
    public static func convert(
        sourceURLs: [URL],
        settings: ConversionSettings,
        outputDirectory: URL? = nil,
        concurrencyLimit: Int = defaultConcurrencyLimit,
        fileManager: FileManager = .default,
        onStatusChange: (@Sendable (_ itemID: UUID, _ status: BatchItemStatus) -> Void)? = nil
    ) async throws -> [BatchItem] {
        guard sourceURLs.count <= maxBatchSize else {
            throw BatchConversionError.batchTooLarge(count: sourceURLs.count, limit: maxBatchSize)
        }

        var items = sourceURLs.map { BatchItem(sourceURL: $0) }
        guard !items.isEmpty else { return items }

        let limit = max(1, concurrencyLimit)

        await withTaskGroup(of: (Int, BatchItemStatus).self) { group in
            var nextIndex = 0

            func startNext() {
                guard nextIndex < items.count else { return }
                let index = nextIndex
                nextIndex += 1
                let url = items[index].sourceURL

                items[index].status = .converting
                onStatusChange?(items[index].id, .converting)

                group.addTask {
                    let destination = outputDirectory ?? url.deletingLastPathComponent()
                    do {
                        let result = try ConversionPipeline.convert(
                            fileAt: url,
                            settings: settings,
                            outputDirectory: destination,
                            fileManager: fileManager
                        )
                        return (index, .done(result))
                    } catch let error as ConversionError {
                        return (index, .failed(error))
                    } catch {
                        return (index, .failed(.encodeFailed))
                    }
                }
            }

            for _ in 0..<min(limit, items.count) {
                startNext()
            }

            while let (index, status) = await group.next() {
                items[index].status = status
                onStatusChange?(items[index].id, status)
                startNext()
            }
        }

        return items
    }
}
