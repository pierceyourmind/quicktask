import AppKit
import SwiftUI

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

    /// Settings window — retained to prevent ARC deallocation on repeated opens.
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Suppress the Dock icon at runtime. This is the reliable approach for
        // SPM-based executables where Info.plist LSUIElement may not be auto-applied.
        // See ARCHITECTURE.md: NSStatusItem + NSPanel pattern, not MenuBarExtra.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        PanelManager.shared.configure(with: TaskStore())
        HotkeyService.shared.register()

        print("[QuickTask] App launched as menu bar agent")
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        // Create the menu bar icon with a fixed square size
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }

        // SF Symbol "checkmark.circle" as the menu bar icon.
        // isTemplate = true ensures macOS applies the correct tint for both light and dark
        // menu bar modes. Template images use only the alpha channel; base color is ignored.
        if let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "QuickTask") {
            image.isTemplate = true
            button.image = image
        }

        // Use handleStatusItemClick to intercept both left-click (panel toggle)
        // and right-click (context menu). IMPORTANT: do NOT set statusItem.menu —
        // setting .menu overrides button.action entirely and breaks left-click panel toggle.
        button.action = #selector(handleStatusItemClick)
        button.target = self

        // Enable both click types in a single action handler.
        // The handler reads NSApp.currentEvent to distinguish left vs right.
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    // MARK: - Status Item Click Handling

    /// Handles all clicks on the menu bar icon.
    /// Right-click (or Ctrl+click) shows the context menu; left-click toggles the floating panel.
    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.isRightClick {
            showContextMenu()
        } else {
            PanelManager.shared.toggle()
        }
    }

    /// Presents the right-click context menu anchored to the status item button.
    ///
    /// IMPORTANT: the menu is shown via popUp(positioning:at:in:) — NOT by setting
    /// statusItem.menu. Setting .menu would override button.action and break left-click.
    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit QuickTask",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        // Pop up the menu anchored to the button in button-local coordinates.
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: .zero, in: button)
    }

    /// Opens a Settings window hosting SettingsView directly via NSWindow + NSHostingView.
    /// Bypasses SwiftUI Settings scene which doesn't work reliably in SPM-built app bundles.
    @objc private func openSettingsFromMenu() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "QuickTask Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        settingsWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - NSEvent Extension

extension NSEvent {
    /// Returns true for right mouse button clicks and Ctrl+click (Control+left click).
    var isRightClick: Bool {
        type == .rightMouseDown || modifierFlags.contains(.control)
    }
}
