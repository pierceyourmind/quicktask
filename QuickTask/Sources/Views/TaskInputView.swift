import SwiftUI
import AppKit

/// TaskInputView provides the text field that captures new tasks.
///
/// Auto-focus behavior:
/// - Uses NSWindow.didBecomeKeyNotification (NOT onAppear) to focus the text field on every
///   panel open. This is required because FloatingPanel reuses the same NSHostingView —
///   orderOut/orderFront does NOT re-trigger onAppear. The notification fires every time the
///   panel becomes the key window, which is exactly what we need.
///
/// Submit behavior:
/// - onSubmit fires when the user presses Return
/// - Calls store.add(title:) — TaskStore already guards against empty/whitespace titles
/// - Clears the text field immediately after submit
/// - Re-focuses the text field so the user can type the next task without clicking
struct TaskInputView: View {

    @Environment(TaskStore.self) private var store
    @FocusState private var inputFocused: Bool
    @State private var text = ""

    var body: some View {
        TextField("Add a task...", text: $text)
            .textFieldStyle(.plain)
            .font(.body)
            .padding()
            .focused($inputFocused)
            .onSubmit {
                submitTask()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            ) { _ in
                // DispatchQueue.main.async is required because the window may not be
                // fully promoted to key window at the exact moment the notification fires.
                DispatchQueue.main.async {
                    inputFocused = true
                }
            }
    }

    // MARK: - Private

    private func submitTask() {
        store.add(title: text)
        text = ""
        // Re-focus so the user can immediately type the next task
        DispatchQueue.main.async {
            inputFocused = true
        }
    }
}
