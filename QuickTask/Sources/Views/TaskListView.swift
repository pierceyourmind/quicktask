import SwiftUI

/// TaskListView displays the complete task list using TaskRowView for each row.
///
/// All tasks are shown in insertion order — completed tasks are never filtered out (TASK-03).
/// Row separators are hidden because TaskRowView provides its own visual structure; default
/// separators add visual noise between checkbox rows.
///
/// An empty state overlay appears automatically when there are no tasks, providing an
/// encouraging placeholder using ContentUnavailableView (macOS 14+ native component).
/// The overlay is driven reactively by @Observable TaskStore — no additional state needed.
struct TaskListView: View {

    @Environment(TaskStore.self) private var store
    @State private var showConfirmation = false

    var body: some View {
        List {
            ForEach(store.tasks) { task in
                TaskRowView(task: task)
                    .listRowSeparator(.hidden)
            }
            .onMove { indices, newOffset in
                store.move(fromOffsets: indices, toOffset: newOffset)
            }
        }
        .listStyle(.plain)
        .overlay {
            if store.tasks.isEmpty {
                ContentUnavailableView(
                    "All clear.",
                    systemImage: "checkmark.circle",
                    description: Text("Add a task to get started.")
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if store.completedCount > 0 {
                HStack {
                    Spacer()
                    Button("Clear \(store.completedCount) completed") {
                        showConfirmation = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    Spacer()
                }
                .background(.regularMaterial)
            }
        }
        .confirmationDialog(
            "Clear completed tasks?",
            isPresented: $showConfirmation
        ) {
            Button("Clear \(store.completedCount) completed", role: .destructive) {
                store.clearCompleted()
            }
        } message: {
            Text("This will permanently remove all completed tasks.")
        }
    }
}
