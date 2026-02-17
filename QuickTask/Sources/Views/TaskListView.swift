import SwiftUI

/// TaskListView displays the current task list in a plain scrollable list.
///
/// This is the minimal implementation for Plan 02 — it shows task titles to satisfy CAPT-04
/// (tasks appear in the list after capture). Plan 03 will replace the `Text(task.title)` body
/// with `TaskRowView(task: task)` to add checkbox, strikethrough, and delete behavior.
struct TaskListView: View {

    @Environment(TaskStore.self) private var store

    var body: some View {
        List(store.tasks) { task in
            Text(task.title)
        }
        .listStyle(.plain)
    }
}
