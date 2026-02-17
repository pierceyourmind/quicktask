import SwiftUI

/// TaskListView displays the complete task list using TaskRowView for each row.
///
/// All tasks are shown in insertion order — completed tasks are never filtered out (TASK-03).
/// Row separators are hidden because TaskRowView provides its own visual structure; default
/// separators add visual noise between checkbox rows.
struct TaskListView: View {

    @Environment(TaskStore.self) private var store

    var body: some View {
        List(store.tasks) { task in
            TaskRowView(task: task)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}
