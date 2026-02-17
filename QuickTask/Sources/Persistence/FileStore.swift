import Foundation

/// FileStore is the low-level persistence layer that reads and writes task data as JSON
/// to ~/Library/Application Support/QuickTask/tasks.json.
///
/// Design notes:
/// - The Application Support subdirectory is NOT automatically created by macOS —
///   FileStore.init() calls createDirectory to ensure it exists before any file operations.
/// - Writes use the .atomic option to prevent data corruption if the app is force-quit
///   mid-write. The OS writes to a temp file and renames atomically.
/// - All errors are silently swallowed (try?) so callers never need to handle I/O errors.
///   An empty task list is the safe fallback on any read failure.
struct FileStore {

    /// The resolved path to tasks.json in the Application Support directory.
    private let fileURL: URL

    init() {
        // Resolve ~/Library/Application Support/QuickTask/
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("QuickTask", isDirectory: true)

        // CRITICAL: Application Support sub-directories are NOT auto-created by macOS.
        // If the directory does not exist, all subsequent file reads/writes will fail silently.
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true,
            attributes: nil
        )

        fileURL = appSupport.appendingPathComponent("tasks.json")
    }

    /// Loads the task list from disk.
    ///
    /// Returns an empty array if the file does not exist (first launch) or if
    /// decoding fails for any reason (corrupted file, schema mismatch).
    func load() -> [Task] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Task].self, from: data)) ?? []
    }

    /// Saves the task list to disk.
    ///
    /// Uses .atomic writes: the OS writes to a temp file first, then renames it
    /// to the destination — ensuring the file is never in a partially-written state.
    func save(_ tasks: [Task]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
