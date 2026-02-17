import SwiftUI

@main
struct QuickTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The real UI lives in the NSPanel created in Plan 02.
        // A minimal Settings scene is required to satisfy SwiftUI's App protocol.
        // We do NOT use MenuBarExtra here — see STACK.md for rationale.
        Settings {
            EmptyView()
        }
    }
}
