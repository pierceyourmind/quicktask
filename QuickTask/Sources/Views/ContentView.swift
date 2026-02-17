import SwiftUI

/// ContentView is a placeholder for the task capture UI.
///
/// This view will be hosted inside the NSPanel created in Plan 02.
/// In Phase 2, it will be replaced with the full task checklist UI:
/// - Text field for quick task entry (type + Enter)
/// - Checklist with checkboxes
/// - Completed tasks dimmed but visible
struct ContentView: View {
    var body: some View {
        Text("QuickTask")
            .font(.title2)
            .foregroundColor(.secondary)
            .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}
