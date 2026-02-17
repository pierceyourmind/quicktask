import AppKit
import SwiftUI

/// PanelManager is the singleton responsible for owning, positioning, and toggling
/// the FloatingPanel. It is the single source of truth for panel visibility state.
///
/// Design notes:
/// - `panel` is `lazy` so the NSPanel and SwiftUI hosting view are created on first use,
///   not at app launch — keeping startup fast.
/// - `orderFrontRegardless()` is required (not `makeKeyAndOrderFront`) because the app
///   runs as .accessory and may not be the active application when the panel is shown.
/// - `makeKey()` grants key-window status to the panel so text fields receive input,
///   without performing a full app activation (which would steal focus visually).
final class PanelManager {

    /// Shared singleton instance — use PanelManager.shared.toggle() from AppDelegate
    /// and the global hotkey handler.
    static let shared = PanelManager()

    private init() {}

    /// Lazily creates the floating panel on first access. Using `lazy` defers NSPanel
    /// initialization until the panel is actually needed.
    private lazy var panel: FloatingPanel<ContentView> = {
        FloatingPanel(rootView: ContentView())
    }()

    /// Tracks whether the panel is currently visible.
    private(set) var isVisible: Bool = false

    /// Toggles the panel between visible and hidden states.
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Positions the panel in Spotlight-style (centered horizontally, slightly above
    /// vertical center) and brings it to front as a key window for text input.
    func show() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 300

        // Center horizontally; position slightly above center vertically (Spotlight-style)
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.midY + screenFrame.height * 0.1

        panel.setFrame(
            NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
            display: true
        )

        // Bring the panel to front even when the app is not the active application.
        // `orderFrontRegardless()` is necessary for .accessory apps.
        panel.orderFrontRegardless()

        // Grant key-window status so embedded text fields receive keyboard input.
        // We use `makeKey()` rather than `makeKeyAndOrderFront(_:)` to avoid a
        // full app activation, which would bring the app to the foreground visually.
        panel.makeKey()

        isVisible = true
    }

    /// Hides the floating panel without destroying it.
    func hide() {
        panel.orderOut(nil)
        isVisible = false
    }
}
