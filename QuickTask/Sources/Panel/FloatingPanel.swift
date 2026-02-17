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
///   user clicks elsewhere. Dismissal is handled by AppDelegate/hotkey logic.
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

        // Dismissal is handled explicitly (icon click / hotkey), not by deactivation
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
}
