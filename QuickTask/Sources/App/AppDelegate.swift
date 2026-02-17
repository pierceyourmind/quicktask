import AppKit

/// AppDelegate manages the core app lifecycle for QuickTask.
///
/// This class is wired to SwiftUI's app lifecycle via @NSApplicationDelegateAdaptor
/// in QuickTaskApp.swift. It is retained for the lifetime of the app.
///
/// Plan 02 will extend this class to hold:
/// - NSStatusItem (strong reference — must live on AppDelegate to avoid deallocation)
/// - PanelManager (manages the floating NSPanel)
/// - KeyboardShortcuts registration
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Suppress the Dock icon at runtime. This is the reliable approach for
        // SPM-based executables where Info.plist LSUIElement may not be auto-applied.
        // See STACK.md: NSStatusItem + NSPanel pattern, not MenuBarExtra.
        NSApp.setActivationPolicy(.accessory)

        print("[QuickTask] App launched as menu bar agent")
    }
}
