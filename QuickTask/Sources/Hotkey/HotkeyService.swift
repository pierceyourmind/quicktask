import KeyboardShortcuts

/// Define the global hotkey name used by KeyboardShortcuts library.
///
/// Cmd+Shift+Space is chosen to avoid conflicts with:
/// - Cmd+Space: Spotlight
/// - Cmd+Shift+3/4/5: Screenshots
/// - Other common system shortcuts
extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.space, modifiers: [.command, .shift]))
}

/// HotkeyService registers the global hotkey that toggles the QuickTask floating panel
/// from any application, including when QuickTask is backgrounded.
///
/// Design notes:
/// - Uses KeyboardShortcuts SPM library (NOT SwiftUI .keyboardShortcut()) because
///   SwiftUI shortcuts only fire when the app is active/foreground. The whole value
///   proposition of QuickTask is that the hotkey works from any app.
/// - Uses `onKeyUp` (not `onKeyDown`) — standard pattern for toggle shortcuts.
/// - KeyboardShortcuts handles Carbon/CGEventTap internals and Input Monitoring permissions.
/// - Deregistration on app quit is handled automatically by the library.
final class HotkeyService {

    /// Shared singleton instance.
    static let shared = HotkeyService()

    private init() {}

    /// Registers the global Cmd+Shift+Space hotkey.
    /// Must be called from `applicationDidFinishLaunching` so the hotkey is active immediately.
    func register() {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) {
            PanelManager.shared.toggle()
        }
    }
}
