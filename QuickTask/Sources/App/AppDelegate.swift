import AppKit

/// AppDelegate manages the core app lifecycle for QuickTask.
///
/// This class is wired to SwiftUI's app lifecycle via @NSApplicationDelegateAdaptor
/// in QuickTaskApp.swift. It is retained for the lifetime of the app.
///
/// IMPORTANT: `statusItem` is stored as an instance property (not a local variable).
/// ARC will silently deallocate a local NSStatusItem after `applicationDidFinishLaunching`
/// returns, causing the menu bar icon to vanish. Storing it here keeps it alive for the
/// lifetime of AppDelegate (i.e., the lifetime of the app).
class AppDelegate: NSObject, NSApplicationDelegate {

    /// Strong reference to the NSStatusItem (menu bar icon).
    /// MUST be an instance property — NOT a local var — to survive ARC.
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Suppress the Dock icon at runtime. This is the reliable approach for
        // SPM-based executables where Info.plist LSUIElement may not be auto-applied.
        // See ARCHITECTURE.md: NSStatusItem + NSPanel pattern, not MenuBarExtra.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        HotkeyService.shared.register()

        print("[QuickTask] App launched as menu bar agent")
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        // Create the menu bar icon with a fixed square size
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }

        // SF Symbol "checkmark.circle" as the menu bar icon.
        // Phase 3 will replace this with a proper template image for light/dark adaptation.
        button.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "QuickTask")
        button.action = #selector(togglePanel)
        button.target = self
    }

    /// Called when the user clicks the menu bar icon.
    @objc private func togglePanel() {
        PanelManager.shared.toggle()
    }
}
