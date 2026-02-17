import AppKit
import SwiftUI

/// FloatingPanel is an NSPanel subclass providing Spotlight-style floating behavior.
///
/// Key design decisions:
/// - `.nonactivatingPanel` style mask allows the panel to appear without activating the app
///   or stealing keyboard focus from the user's current application.
/// - `canBecomeKey` returns `true` so text fields inside the hosted SwiftUI view can receive
///   keyboard input even though the app runs as a background agent (.accessory policy).
/// - `isReleasedWhenClosed = false` prevents ARC from releasing the panel on `orderOut(_:)`,
///   which would cause a crash on the next toggle (Pitfall from ARCHITECTURE.md).
/// - `hidesOnDeactivate = false` ensures explicit dismissal rather than auto-hide when the
///   user clicks elsewhere. Dismissal is handled by PanelManager.shared.hide().
/// - `resignKey()` detects when the panel loses key-window status (user clicked elsewhere)
///   and triggers PanelManager.shared.hide() so focus returns to the previous app.
class FloatingPanel<Content: View>: NSPanel {

    init(rootView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [
                .nonactivatingPanel,   // CRITICAL: panel appears without stealing app focus
                .titled,
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        // Keep the panel above regular windows at all times
        isFloatingPanel = true
        level = .floating

        // Allow panel to appear over fullscreen apps; exclude from Mission Control
        collectionBehavior.insert(.fullScreenAuxiliary)
        collectionBehavior.insert(.transient)

        // Hide the title bar text and make it seamlessly transparent
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Allow the user to drag the panel by clicking anywhere on its background
        isMovableByWindowBackground = true

        // CRITICAL: prevents ARC from releasing the panel when closed via orderOut(_:).
        // Without this, calling show() a second time after hide() would access a
        // deallocated object and crash.
        isReleasedWhenClosed = false

        // Dismissal is handled explicitly via PanelManager.shared.hide(), not by deactivation.
        // resignKey() below provides a safety net for cases where deactivation-based
        // dismissal is desired (user clicks another app window).
        hidesOnDeactivate = false

        // SwiftUI content provides its own background styling
        backgroundColor = .clear

        hasShadow = true

        // Bridge SwiftUI content into AppKit panel
        contentView = NSHostingView(rootView: rootView)
    }

    /// CRITICAL: Must return true so that text fields inside the hosted SwiftUI view
    /// can receive keyboard input. Without this override, NSPanel does not become key
    /// and all text input into any NSTextField / SwiftUI TextField is silently ignored.
    override var canBecomeKey: Bool { true }

    /// Returning false prevents the panel from becoming the "main" window, which would
    /// interfere with the previously active application's main-window status.
    override var canBecomeMain: Bool { false }

    /// Handle keyboard events. Escape (keyCode 53) closes the panel.
    /// All other keys are passed to super so normal text input continues to work.
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // 53 = Escape key
            PanelManager.shared.hide()
        } else {
            super.keyDown(with: event)
        }
    }

    /// Called when the panel loses key-window status — e.g., user clicks another
    /// application's window or another window becomes key.
    ///
    /// PanelManager.hide() is idempotent, so it is safe to call even if the global
    /// click monitor already triggered hide() a moment earlier. The `guard isVisible`
    /// check in PanelManager.hide() prevents double-dismiss side effects.
    override func resignKey() {
        super.resignKey()
        if isVisible {
            PanelManager.shared.hide()
        }
    }
}
