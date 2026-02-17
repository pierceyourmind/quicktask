import Foundation

/// TaskRepository is the CRUD abstraction layer between TaskStore and FileStore.
///
/// This layer is intentionally thin — it delegates all I/O to FileStore.
/// Its purpose is to serve as an abstraction boundary: if the storage backend
/// ever changes (e.g., from JSON files to CloudKit), only this file needs to change.
/// TaskStore is insulated from FileStore's concrete implementation details.
struct TaskRepository {

    private let store = FileStore()

    /// Loads all tasks from persistent storage.
    func loadAll() -> [Task] {
        store.load()
    }

    /// Saves the complete task list to persistent storage.
    ///
    /// TaskStore always saves the full list on every mutation — not individual changes.
    /// This keeps the persistence logic simple and correct for < 500 tasks.
    func save(_ tasks: [Task]) {
        store.save(tasks)
    }
}
