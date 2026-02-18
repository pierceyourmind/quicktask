import AppKit
import SwiftUI

/// PanelManager is the singleton responsible for owning, positioning, and toggling
/// the FloatingPanel. It is the single source of truth for panel visibility state.
///
/// Design notes:
/// - `panel` is created in `configure(with:)` rather than lazily at first access.
///   This allows TaskStore to be injected into the SwiftUI environment before the panel
///   is shown for the first time.
/// - `orderFrontRegardless()` is required (not `makeKeyAndOrderFront`) because the app
///   runs as .accessory and may not be the active application when the panel is shown.
/// - `makeKey()` grants key-window status to the panel so text fields receive input,
///   without performing a full app activation (which would steal focus visually).
/// - `previousApp` captures the frontmost app before the panel appears so focus can be
///   returned to it on every dismissal path (Escape, click-outside, hotkey toggle).
final class PanelManager {

    /// Shared singleton instance — use PanelManager.shared.toggle() from AppDelegate
    /// and the global hotkey handler.
    static let shared = PanelManager()

    private init() {}

    /// The floating panel. Created in configure(with:) when the TaskStore is available.
    /// Optional so that methods are safe to call before configure(with:) completes (guards below).
    private var panel: FloatingPanel<AnyView>?

    /// The TaskStore injected at app launch via configure(with:).
    private var taskStore: TaskStore?

    /// Tracks whether the panel is currently visible.
    /// `hide()` checks this guard to remain idempotent — safe to call multiple times.
    private(set) var isVisible: Bool = false

    /// The application that was frontmost before the panel appeared.
    /// Captured in show() and used in hide() to return focus to the user's previous context.
    private var previousApp: NSRunningApplication?

    /// Global mouse-click monitor for detecting clicks outside the panel.
    /// Installed in show(), removed in hide().
    private var clickMonitor: Any?

    /// Configures the panel manager with the shared TaskStore.
    ///
    /// Called once from AppDelegate.applicationDidFinishLaunching. Creates the
    /// FloatingPanel with ContentView injected into the SwiftUI environment so that
    /// all descendant views can access TaskStore via @Environment(TaskStore.self).
    ///
    /// CRITICAL: The `.environment(store)` call on the rootView is what makes
    /// `@Environment(TaskStore.self)` work in child views. NSHostingView creates
    /// an isolated SwiftUI environment — the store MUST be injected here, not from
    /// QuickTaskApp's body (which is just `Settings { EmptyView() }`).
    func configure(with store: TaskStore) {
        self.taskStore = store
        panel = FloatingPanel(rootView: AnyView(ContentView().environment(store)))
    }

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
        guard let panel else { return }
        guard let screen = NSScreen.main else { return }

        // Capture the frontmost app BEFORE showing — once our panel becomes key,
        // NSWorkspace.shared.frontmostApplication changes to QuickTask (or nil for .accessory apps).
        previousApp = NSWorkspace.shared.frontmostApplication

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

        // Safety reset: ensure panel is fully opaque before showing.
        // A rapid show/hide toggle can leave alphaValue stuck at 0 if a previous
        // hide animation was interrupted mid-fade. Resetting here guarantees a
        // visible panel regardless of animation state.
        panel.alphaValue = 1.0

        // Bring the panel to front even when the app is not the active application.
        // `orderFrontRegardless()` is necessary for .accessory apps.
        panel.orderFrontRegardless()

        // Grant key-window status so embedded text fields receive keyboard input.
        // We use `makeKey()` rather than `makeKeyAndOrderFront(_:)` to avoid a
        // full app activation, which would bring the app to the foreground visually.
        panel.makeKey()

        isVisible = true

        // Monitor for clicks in OTHER applications' windows to dismiss the panel.
        // `addGlobalMonitorForEvents` (not Local) fires when the user clicks anywhere
        // outside our app's windows. We do NOT need a local monitor — clicks within
        // the panel should NOT dismiss it.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.isVisible else { return }
            self.hide()
        }
    }

    /// Hides the floating panel without destroying it, and returns focus to the
    /// previously active application.
    ///
    /// This method is idempotent: calling it when the panel is already hidden is safe.
    /// Multiple dismissal paths (Escape, click-outside global monitor, resignKey,
    /// hotkey toggle) may call hide() in rapid succession — the guard prevents
    /// double-dismiss side effects.
    func hide() {
        guard isVisible else { return }

        // Remove the click monitor first to prevent it from firing during our own hide
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }

        panel?.orderOut(nil)
        isVisible = false

        // Return focus to the app that was active before the panel appeared.
        // `.activate(options: [])` is used (not `.activateIgnoringOtherApps`)
        // because we just hid our panel and the gentle activation is sufficient.
        previousApp?.activate()
        previousApp = nil
    }
}
