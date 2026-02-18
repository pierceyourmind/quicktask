import SwiftUI

@main
struct QuickTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible scenes — the app is driven entirely by AppDelegate (NSStatusItem + NSPanel).
        // Settings window is managed as an NSWindow in AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
