import Foundation
import Observation

/// TaskStore is the single source of truth for the task list in QuickTask.
///
/// It is @Observable (macOS 14+ Swift 5.9+ pattern) — NOT ObservableObject/Combine.
/// Views read `tasks` directly; the @Observable macro generates the change notifications.
///
/// Ownership:
/// - Created once in AppDelegate.applicationDidFinishLaunching
/// - Passed to PanelManager via configure(with:)
/// - Injected into the SwiftUI environment via .environment(store) on the hosting view
/// - Accessed in child views via @Environment(TaskStore.self)
///
/// Design notes:
/// - All mutations call persist() synchronously. This is acceptable for < 500 tasks
///   (research confirmed JSON encode+write of 500 tasks completes in < 1ms).
/// - add() guards against whitespace-only titles to avoid empty task creation.
/// - No @Published, no Combine, no @StateObject anywhere in this class.
@Observable final class TaskStore {

    /// The complete, ordered task list. The @Observable macro tracks reads and writes
    /// to this property and notifies SwiftUI views that depend on it.
    var tasks: [Task] = []

    private let repository = TaskRepository()

    /// On init, immediately load persisted tasks from disk.
    init() {
        tasks = repository.loadAll()
    }

    // MARK: - Computed Properties

    /// The count of tasks that have not yet been completed.
    ///
    /// Computed from `tasks` — the @Observable macro tracks reads of `tasks` here,
    /// so any withObservationTracking call that reads `incompleteCount` will re-fire
    /// whenever `tasks` mutates (add, toggle, delete).
    var incompleteCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    // MARK: - Mutations

    /// Appends a new task with the given title.
    ///
    /// Silently ignores whitespace-only titles — the text field UI enforces non-empty
    /// input, but this guard ensures correctness even if called programmatically.
    func add(title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        tasks.append(Task(title: title))
        persist()
    }

    /// Toggles the isCompleted state of the given task.
    func toggle(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
        persist()
    }

    /// Removes the given task from the list.
    func delete(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    // MARK: - Persistence

    /// Saves the full task list to disk. Called after every mutation.
    private func persist() {
        repository.save(tasks)
    }
}
