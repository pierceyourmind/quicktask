import SwiftUI

// Notification name used to bridge AppKit (AppDelegate) to SwiftUI (HiddenWindowView).
// AppDelegate posts this when "Settings..." is selected from the right-click context menu.
extension Notification.Name {
    static let openSettingsRequest = Notification.Name("OpenSettingsRequest")
}

/// A hidden 1x1 window that provides SwiftUI environment context for @Environment(\.openSettings).
///
/// This workaround is required on macOS 14+ because @Environment(\.openSettings) cannot be
/// called from AppKit code (e.g., AppDelegate). AppDelegate posts .openSettingsRequest via
/// NotificationCenter, and this view receives it and calls openSettings().
///
/// CRITICAL: This Window scene MUST be declared FIRST in the App body. SwiftUI resolves scenes
/// and propagates environment in declaration order — the Settings {} scene requires this context.
struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                Swift.Task { @MainActor in
                    // Must switch to .regular so macOS brings the Settings window to front.
                    // See: Peter Steinberger "Showing Settings from macOS Menu Bar Items: A 5-Hour Journey"
                    NSApp.setActivationPolicy(.regular)
                    try? await Task.sleep(for: .milliseconds(100))
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                    // Restore after a brief pause for the settings window to appear.
                    try? await Task.sleep(for: .milliseconds(200))
                    NSApp.setActivationPolicy(.accessory)
                }
            }
    }
}

@main
struct QuickTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // MUST be declared first — provides @Environment(\.openSettings) context for the Settings scene.
        // This 1x1 hidden window is ordered out in AppDelegate.applicationDidFinishLaunching.
        Window("", id: "hidden-settings-bridge") {
            HiddenWindowView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        // Settings scene — the actual preferences UI.
        // Opened indirectly via NotificationCenter from AppDelegate right-click handler.
        Settings {
            SettingsView()
        }
    }
}
