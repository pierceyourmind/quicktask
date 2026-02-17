import SwiftUI

/// TaskRowView displays a single task as a row with a native macOS checkbox, strikethrough text
/// for completed tasks, a full-row opacity fade, and a delete button.
///
/// Design decisions:
/// - `.toggleStyle(.checkbox)` — native macOS checkbox per HIG. macOS-only API, confirmed available.
/// - The Toggle label (`Text(task.title)`) receives `.strikethrough(task.isCompleted)` — strikethrough
///   is on the text, not the row.
/// - `.opacity(task.isCompleted ? 0.4 : 1.0)` is on the outer HStack — the entire row fades, not
///   just the text, giving a clear "done and deprioritized" signal.
/// - `.animation(.easeInOut(duration: 0.2))` on opacity for a smooth visual transition.
/// - The delete button uses `.buttonStyle(.plain)` to avoid the default button chrome that appears
///   inside List rows. `.help("Delete task")` provides an accessibility tooltip.
/// - Completed tasks are NEVER filtered — only visual styling changes (TASK-03 requirement).
struct TaskRowView: View {

    @Environment(TaskStore.self) private var store

    let task: Task

    var body: some View {
        HStack {
            Toggle(
                isOn: Binding(
                    get: { task.isCompleted },
                    set: { _ in store.toggle(task) }
                )
            ) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
            }
            .toggleStyle(.checkbox)

            Spacer()

            Button {
                store.delete(task)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete task")
        }
        .opacity(task.isCompleted ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
    }
}
