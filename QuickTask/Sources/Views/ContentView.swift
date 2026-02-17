import SwiftUI

/// ContentView is the root layout of the QuickTask floating panel.
///
/// Layout: VStack with TaskInputView (text capture), a Divider, and TaskListView (task list).
/// Fixed 400x300 frame matches the FloatingPanel size from Phase 1 — dynamic sizing is
/// deferred to Phase 3 polish.
///
/// Background: .regularMaterial provides the frosted glass appearance matching Spotlight style.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            TaskInputView()
            Divider()
            TaskListView()
        }
        .frame(width: 400, height: 300)
        .background(.regularMaterial)
    }
}
