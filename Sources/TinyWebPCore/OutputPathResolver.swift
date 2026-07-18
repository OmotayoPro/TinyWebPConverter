import Foundation

/// PRD §6.5: if the output already exists, auto-rename with an incrementing number rather than
/// overwriting or prompting.
enum OutputPathResolver {
    static func resolve(
        baseName: String,
        extension ext: String,
        directory: URL,
        fileManager: FileManager = .default
    ) -> URL {
        var candidate = directory.appendingPathComponent("\(baseName).\(ext)")
        var attempt = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) (\(attempt)).\(ext)")
            attempt += 1
        }
        return candidate
    }
}
