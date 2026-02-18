# Phase 3: Settings, Launch at Login, and v1 Polish - Research

**Researched:** 2026-02-17
**Domain:** SMAppService, SwiftUI Settings window workaround, NSStatusItem right-click menus, Defaults SPM, NSPanel animation, empty state UI (macOS 14+)
**Confidence:** HIGH (all major patterns verified against official docs and authoritative community sources; one MEDIUM area noted for Settings window timing)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SETT-01 | Launch at login toggle (opt-in, defaults to off) | `SMAppService.mainApp.register()` / `.unregister()` / `.status` — verified Apple API (macOS 13+). Query status at runtime, never store locally. |
| SETT-02 | Settings accessible from menu bar icon context menu | Right-click NSStatusItem using `sendAction(on: [.leftMouseDown, .rightMouseDown])` + `NSApp.currentEvent?.isRightClick` check. Settings window opened via hidden SwiftUI `Window` scene declared before `Settings {}` in App body. |
</phase_requirements>

---

## Summary

Phase 3 adds three distinct capabilities: a Settings window, launch-at-login, and UI polish. Each has its own technical domain but they interact: the Settings window hosts the launch-at-login toggle, the NSStatusItem right-click menu opens the Settings window, and the UI polish touches the content panel and empty state.

The **Settings window** is the most technically subtle problem. Apple's `openSettings()` environment action and the old `NSApp.sendAction(#selector(NSApplication.showSettingsWindow:))` both fail silently in menu bar apps on macOS 14+. The working workaround is a hidden 1x1 SwiftUI `Window` scene declared as the *first* scene in the App body, which provides SwiftUI environment context for `@Environment(\.openSettings)`. This hidden window posts via `NotificationCenter` when triggered from the NSStatusItem right-click menu. The sequence requires temporarily switching `NSApp.setActivationPolicy(.regular)`, a ~100ms delay, activating the app, then calling `openSettings()`. After the Settings window closes, the policy reverts to `.accessory`.

**Launch at login** via `SMAppService.mainApp` is clean and well-documented for macOS 13+. The key rule is: query `.status` at runtime rather than storing a Bool in `Defaults`. The toggle UI reads from `SMAppService.mainApp.status == .enabled`; writing calls `register()` or `unregister()`. The `requiresApproval` status means the user registered but must approve in System Settings — the UI should show this distinct state.

**NSStatusItem right-click** requires configuring the button's `sendAction(on: [.leftMouseDown, .rightMouseDown])` and distinguishing click types in the handler via `NSApp.currentEvent`. You cannot use both `.button.action` and `.menu` on the same `NSStatusItem` — the `.menu` property overrides the button action entirely.

**Primary recommendation:** Follow the locked architectural constraints exactly: hidden `Window` scene first in App body, `SMAppService.mainApp.status` queried at runtime, `Defaults` for any additional persisted preferences (not launch-at-login which uses SMAppService as its own source of truth), and `@Default` in SwiftUI views.

---

## Standard Stack

### Core (No New SPM Dependencies)
| Component | API / Version | Purpose | Why Standard |
|-----------|--------------|---------|--------------|
| `SMAppService` | ServiceManagement (macOS 13+) | Launch at login register/unregister/status | Apple-blessed replacement for deprecated SMLoginItemSetEnabled; no helper app needed |
| `Defaults` | 9.0.6 (already in Package.swift) | Type-safe UserDefaults for any preferences beyond launch-at-login | Already a dependency; avoids raw UserDefaults stringly-typed access |
| `@Environment(\.openSettings)` | SwiftUI (macOS 14+) | Open the `Settings {}` scene | Only working programmatic path on macOS 14+ |
| `NSStatusItem` + `sendAction(on:)` | AppKit | Right-click context menu on status bar icon | Existing pattern; extended to handle both click types |
| `ContentUnavailableView` | SwiftUI (macOS 14+) | Empty task list placeholder | Native macOS 14+ empty state; matches HIG; no custom code needed |
| `NSWindow.animationBehavior` | AppKit | Smooth panel show/hide animation | Built-in NSWindow property; `.utilityWindow` provides appropriate animation for floating panels |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `@Default` property wrapper | Bind Defaults key to SwiftUI view | Use in SettingsView for any toggles/settings beyond launch-at-login |
| `NSAnimationContext` | Animate NSPanel alpha (fade in/out) | If SwiftUI `.transition(.opacity)` alone is not smooth enough in the NSHostingView context |
| `NotificationCenter` custom notification | Decouple AppDelegate right-click from SwiftUI hidden window | Required because AppDelegate cannot call `@Environment(\.openSettings)` directly |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hidden `Window` scene workaround | `sindresorhus/Settings` SPM package | The Settings package creates its own NSWindowController, bypasses SwiftUI `Settings {}` scene entirely — valid but adds a dependency and changes the architecture. The hidden window workaround keeps us in the SwiftUI `Settings {}` scene model the app already uses. |
| Hidden `Window` scene workaround | Manual NSWindow for Settings in AppDelegate | Technically simpler — create `NSWindow(contentRect:...)` directly in AppDelegate and call `makeKeyAndOrderFront`. No activation policy juggling needed. This is a legitimate approach but loses `Settings {}` scene benefits. |
| `SMAppService.mainApp` | `LaunchAtLogin` SPM package | The package wraps SMAppService anyway; unnecessary dependency when Apple's API is clean enough to use directly |
| `ContentUnavailableView` | Custom `VStack` with `Text("All clear.")` | Custom view works but requires more code; `ContentUnavailableView` is the HIG-blessed approach for macOS 14+ |

**Installation:** No new packages needed. `Defaults` is already in `Package.swift`.

---

## Architecture Patterns

### Recommended Project Structure (Additions to Phase 2)

```
QuickTask/Sources/
├── App/
│   ├── QuickTaskApp.swift         # MODIFY: add hidden Window scene BEFORE Settings {}
│   └── AppDelegate.swift          # MODIFY: right-click menu, open-settings notification
├── Panel/
│   ├── FloatingPanel.swift        # MODIFY: add animationBehavior for smooth show/hide
│   └── PanelManager.swift         # MODIFY: add fade animation on show/hide
├── Settings/
│   └── SettingsView.swift         # NEW: SwiftUI settings content with launch-at-login toggle
├── Views/
│   ├── ContentView.swift          # MODIFY: add empty state via ContentUnavailableView
│   ├── TaskInputView.swift        # no changes
│   ├── TaskListView.swift         # MODIFY: empty state overlay
│   └── TaskRowView.swift          # no changes
└── Hotkey/
    └── HotkeyService.swift        # no changes
```

### Pattern 1: Hidden Window Scene for Settings Access

**What:** A hidden SwiftUI `Window` scene declared as the FIRST scene in the App body. It provides SwiftUI environment context (`@Environment(\.openSettings)`) that is not available in AppKit code. A `NotificationCenter` notification bridges AppKit (AppDelegate's right-click handler) to SwiftUI (the hidden window's `onReceive` listener).

**Why this order matters:** SwiftUI resolves scenes and propagates environment in declaration order. The `@Environment(\.openSettings)` action needs the hidden window's render context to be established before the `Settings {}` scene is processed.

**When to use:** Any time AppKit code (AppDelegate, NSStatusItem handler) needs to open a SwiftUI `Settings {}` scene on macOS 14+.

**Complete Pattern:**

```swift
// Source: Peter Steinberger "Showing Settings from macOS Menu Bar Items: A 5-Hour Journey" (2025)
// and Apple openSettings docs (macOS 14+)

// Step 1: Define the notification
extension Notification.Name {
    static let openSettingsRequest = Notification.Name("OpenSettingsRequest")
}

// Step 2: Hidden window view with openSettings access
struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(
                NotificationCenter.default.publisher(for: .openSettingsRequest)
            ) { _ in
                Task { @MainActor in
                    // Must switch to .regular so macOS brings the Settings window to front
                    NSApp.setActivationPolicy(.regular)
                    try? await Task.sleep(for: .milliseconds(100))
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                    // Restore after a brief pause for the settings window to appear
                    try? await Task.sleep(for: .milliseconds(200))
                    NSApp.setActivationPolicy(.accessory)
                }
            }
    }
}

// Step 3: App body — CRITICAL order: hidden Window FIRST, then Settings
@main
struct QuickTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // MUST be declared first — provides environment context
        Window("", id: "hidden-settings-bridge") {
            HiddenWindowView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        // Settings scene with real UI
        Settings {
            SettingsView()
        }
    }
}

// Step 4: AppDelegate right-click handler posts the notification
@objc func openSettingsFromMenu() {
    NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
}
```

**Caveat (MEDIUM confidence on timing):** The 100ms and 200ms delays are empirically derived from community research and Peter Steinberger's testing. On slow machines or macOS version variations, timing may need adjustment. The approach works on macOS 14–15.x but was reported to have issues on macOS 26 (Tahoe beta) — relevant only if targeting future OS.

**Simpler alternative if timing proves unreliable:** Skip the `Settings {}` scene entirely. In AppDelegate, create an `NSWindow` directly:

```swift
// Source: Apple Developer Forums thread 739831 pattern
private var settingsWindow: NSWindow?

func openSettings() {
    if settingsWindow == nil {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: SettingsView())
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
    }
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
}
```

This approach avoids all SwiftUI scene machinery and is simpler. The planner should prefer the hidden-window pattern (as the phase constraints specify) but document this as the fallback.

---

### Pattern 2: NSStatusItem Right-Click Menu (Left-Click Preserved)

**What:** The existing NSStatusItem uses `button.action` for left-click (panel toggle). Adding a `.menu` to the status item would override the button action entirely. Instead, configure `sendAction(on:)` to intercept both click types in a single handler.

**Critical constraint:** Cannot use `statusItem.menu = menu` AND `statusItem.button?.action` simultaneously — `menu` overrides the button action.

```swift
// Source: Jesse Squires "Implementing right-click for NSButton" (2019), still valid pattern
// Source: NSStatusItem docs (AppKit)

// NSEvent extension for clean right-click detection
extension NSEvent {
    var isRightClick: Bool {
        type == .rightMouseDown || modifierFlags.contains(.control)
    }
}

// In AppDelegate.applicationDidFinishLaunching, after creating statusItem:
if let button = statusItem.button {
    let icon = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "QuickTask")
    icon?.isTemplate = true        // CRITICAL: template image for light/dark menu bar support
    button.image = icon
    button.action = #selector(handleStatusItemClick)
    button.target = self
    // Enable both click types — handler distinguishes them
    button.sendAction(on: [.leftMouseDown, .rightMouseDown])
}

// Handler method
@objc private func handleStatusItemClick() {
    guard let event = NSApp.currentEvent else { return }
    if event.isRightClick {
        showContextMenu()
    } else {
        PanelManager.shared.toggle()
    }
}

// Context menu for right-click
private func showContextMenu() {
    let menu = NSMenu()
    menu.addItem(NSMenuItem(
        title: "Settings...",
        action: #selector(openSettingsFromMenu),
        keyEquivalent: ","
    ))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(
        title: "Quit QuickTask",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    ))
    // Pop up the menu at the button's location
    if let button = statusItem.button {
        let location = button.convert(button.bounds.origin, to: nil)
        menu.popUp(positioning: nil, at: location, in: button.window)
    }
}
```

**Template image requirement:** `icon?.isTemplate = true` must be set so macOS automatically applies the correct tint for both light and dark menu bar modes. Template images use only the alpha channel; the base color is ignored. SF Symbol images created with `NSImage(systemSymbolName:)` are automatically template images — verify this is still applied correctly.

---

### Pattern 3: SMAppService Launch at Login

**What:** Apple's official launch-at-login API for macOS 13+. Replaces `SMLoginItemSetEnabled`. No helper app required. `SMAppService.mainApp` represents the main application itself as a login item.

**Key rule:** Never store the launch-at-login state in `Defaults` or UserDefaults. Always query `SMAppService.mainApp.status` at runtime because the user can toggle it in System Settings independently.

```swift
// Source: Apple ServiceManagement framework docs + nilcoalescing.com "Add launch at login setting"
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Registration failed — revert the toggle state
                            launchAtLogin = !newValue
                        }
                    }
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            syncLaunchAtLoginState()
        }
        .onChange(of: NSApp.isActive) { _, isActive in
            // Re-sync when app regains focus (user may have changed it in System Settings)
            if isActive { syncLaunchAtLoginState() }
        }
    }

    private func syncLaunchAtLoginState() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
```

**SMAppService.Status cases:**
| Status | Meaning | UI Response |
|--------|---------|-------------|
| `.enabled` | Registered and will run at login | Toggle = ON |
| `.requiresApproval` | Registered but user must approve in System Settings | Toggle = ON (grayed out with info label) |
| `.notRegistered` | Not registered (default state) | Toggle = OFF |
| `.notFound` | Framework can't find this service (unusual — app may not be properly bundled) | Toggle = OFF, log warning |

**Error handling:** `register()` and `unregister()` throw `Error`. Catch and revert the toggle state on failure. On development builds (non-sandboxed SPM app), `register()` may return `.requiresApproval` on first use — this is expected; the user approves in System Settings > General > Login Items.

**No special entitlements needed** for `SMAppService.mainApp` (main app login item). Entitlements are only needed for daemon or agent registrations.

**Development caveat (LOW confidence):** Development builds (swift build / swift run) may behave differently from distribution builds for SMAppService because the app bundle identity is used to match the login item. Test with a proper `swift build -c release` binary in an app bundle structure.

---

### Pattern 4: SettingsView Structure

```swift
// Source: Apple SwiftUI Form docs, macOS 14 guidelines
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        handleLaunchAtLoginChange(newValue)
                    }
                if SMAppService.mainApp.status == .requiresApproval {
                    Text("Approval required in System Settings > General > Login Items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("General")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, minHeight: 150)
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private func handleLaunchAtLoginChange(_ newValue: Bool) {
        do {
            if newValue { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = !newValue
        }
    }
}
```

**`Form` with `.formStyle(.grouped)`** is the HIG-recommended approach for macOS settings panels — it creates the bordered, grouped appearance matching System Settings panes.

---

### Pattern 5: Empty State with ContentUnavailableView

**What:** `ContentUnavailableView` is a built-in SwiftUI component (macOS 14+) that shows a centered icon + title + description when content is unavailable. Used as an overlay on `TaskListView` when `tasks` is empty.

```swift
// Source: Apple SwiftUI docs — ContentUnavailableView (macOS 14+)
import SwiftUI

struct TaskListView: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        List(store.tasks) { task in
            TaskRowView(task: task)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .overlay {
            if store.tasks.isEmpty {
                ContentUnavailableView(
                    "All clear.",
                    systemImage: "checkmark.circle",
                    description: Text("Add a task to get started.")
                )
                .foregroundStyle(.secondary)
            }
        }
    }
}
```

**Why `ContentUnavailableView` over a custom `Text` view:**
- Automatically uses HIG-compliant layout (icon above title above description)
- Accessible by default
- Animates in/out with the list

**Availability:** `@available(iOS 17.0, macOS 14.0, *)` — matches the project's minimum target.

---

### Pattern 6: Smooth Panel Animation

**What:** The NSPanel currently uses `orderFrontRegardless()` (instant appearance) and `orderOut(nil)` (instant disappearance). Smooth animation requires either:
(a) Setting `animationBehavior` on the panel, or
(b) Animating the panel's `alphaValue` via `NSAnimationContext` before/after ordering.

**Approach A — NSWindow.animationBehavior (simplest):**

```swift
// Source: Apple AppKit docs — NSWindow.animationBehavior
// In FloatingPanel.init():
self.animationBehavior = .utilityWindow
// Then PanelManager uses orderFront/orderOut normally —
// macOS handles the fade animation automatically
```

`NSWindow.AnimationBehavior.utilityWindow` is designed for auxiliary floating panels — it provides a subtle fade-in/fade-out. This requires changing `orderFrontRegardless()` to `orderFront(nil)` in PanelManager.

**Approach B — Manual alpha animation (more control):**

```swift
// Source: Apple NSAnimationContext docs
// In PanelManager.show():
panel.alphaValue = 0
panel.orderFrontRegardless()
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.15
    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
    panel.animator().alphaValue = 1.0
}

// In PanelManager.hide():
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.1
    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
    panel.animator().alphaValue = 0.0
} completionHandler: {
    panel.orderOut(nil)
    panel.alphaValue = 1.0  // Reset for next show
}
```

**Recommendation:** Use Approach A (`animationBehavior = .utilityWindow`) first — it's one line in the existing `FloatingPanel.init()` and relies on macOS's native animation. If the result feels wrong (wrong timing, wrong easing), switch to Approach B for explicit control.

**Note:** `isVisible` tracking in PanelManager must account for animation duration — don't call `hide()` mid-animation.

---

### Pattern 7: Menu Bar Icon as Template Image

The phase constraints require the menu bar icon to be a template image (`.isTemplate = true`) so macOS applies the correct tint for light/dark menu bar automatically.

```swift
// Source: Apple NSStatusBar documentation
// In AppDelegate after creating the status item:
if let button = statusItem.button {
    if let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "QuickTask") {
        image.isTemplate = true  // macOS tints automatically for light/dark
        button.image = image
    }
}
```

**SF Symbols created with `NSImage(systemSymbolName:)`** are template images by default (Apple sets `isTemplate = true` automatically). Verify this if the icon looks wrong in one mode.

For custom images in Assets.xcassets: set **Render As → Template Image** in the asset inspector.

---

### Anti-Patterns to Avoid

- **Setting `statusItem.menu`:** This disables `button.action`. You must use the `sendAction(on:)` + `handleStatusItemClick()` pattern to preserve left-click panel toggle while adding right-click menu.
- **Storing launch-at-login Bool in Defaults:** Use `SMAppService.mainApp.status` as the source of truth. Storing locally leads to stale UI if the user changes it in System Settings.
- **Calling `openSettings()` from AppDelegate directly:** `@Environment(\.openSettings)` only works inside a SwiftUI view in the render tree. It cannot be called from AppKit code. The `NotificationCenter` bridge is required.
- **Forgetting to restore `.accessory` activation policy:** If the Settings window closes and `.regular` is still active, the app appears in the Dock unexpectedly. Always restore `.accessory` after the Settings window appears.
- **Declaring Settings scene before hidden Window scene:** The hidden window must be the first scene — order is critical for SwiftUI environment propagation.
- **Using `orderFront(nil)` without Accessibility entitlement:** `.accessory` policy apps need `orderFrontRegardless()` for the panel (existing behavior). Only the Settings window needs the temporary `.regular` policy for correct ordering.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Launch at login | Custom Launch Agent plist, LoginItems helper | `SMAppService.mainApp` | Apple's API handles all registration, system integration, status tracking; no helper app needed |
| Empty state UI | Custom `VStack { Spacer(); Text(...); Spacer() }` | `ContentUnavailableView` | Native HIG-compliant component; automatic layout, icon+title+description, accessibility |
| Settings window | Custom NSWindow created manually (unless fallback needed) | SwiftUI `Settings {}` scene + hidden window workaround | Consistent with existing SwiftUI App body; HIG standard preferences chrome |
| Right-click detection | Custom NSView subclass for the status item | `sendAction(on: [.leftMouseDown, .rightMouseDown])` + `NSApp.currentEvent?.isRightClick` | Single handler method, no custom view needed |
| UserDefaults key strings | Raw string literals in UserDefaults calls | `Defaults` with `extension Defaults.Keys` | Compile-time type safety, no typos, default values co-located with key declaration |

**Key insight:** Every problem in Phase 3 has a first-party Apple solution or a well-established community pattern. No new SPM dependencies are needed.

---

## Common Pitfalls

### Pitfall 1: statusItem.menu Overrides Button Action

**What goes wrong:** Developer adds `statusItem.menu = contextMenu` to support right-click Settings. Left-click now shows the menu instead of toggling the panel.

**Why it happens:** When `NSStatusItem.menu` is non-nil, macOS routes ALL clicks to the menu — `button.action` is never called.

**How to avoid:** Never set `statusItem.menu`. Use `button.sendAction(on: [.leftMouseDown, .rightMouseDown])` and distinguish click types in the handler via `NSApp.currentEvent`. The menu is shown manually via `menu.popUp(positioning:at:in:)`.

**Warning signs:** Hotkey toggle still works, but left-clicking the menu bar icon shows a menu instead of the panel.

---

### Pitfall 2: Settings Window Opens But Stays Behind Other Windows

**What goes wrong:** `openSettings()` is called and the Settings window appears, but it's behind the frontmost application's window. User has to click the Dock or menu bar to bring it forward.

**Why it happens:** `.accessory` policy apps cannot bring windows to the front reliably without becoming the front app. The Settings window creates but doesn't gain focus.

**How to avoid:** The hidden window sequence: set `.regular` policy → 100ms sleep → `NSApp.activate(ignoringOtherApps: true)` → `openSettings()`. The activation must happen BEFORE `openSettings()`.

**Warning signs:** Settings window appears in Mission Control / Dock switcher but is not visible above other windows.

---

### Pitfall 3: Launch-at-Login State Stale After User Changes System Settings

**What goes wrong:** User enables launch-at-login in the app. User then goes to System Settings > General > Login Items and removes QuickTask. App still shows the toggle as ON.

**Why it happens:** If the app stores the Boolean in `Defaults`, it never re-queries `SMAppService.mainApp.status` after the system-level change.

**How to avoid:** Query `SMAppService.mainApp.status` in:
- `SettingsView.onAppear`
- When the app regains focus (`.onChange(of: NSApp.isActive)`)

Never store the Boolean in `Defaults` as the source of truth.

**Warning signs:** Toggle shows ON but launch-at-login doesn't work after a reboot.

---

### Pitfall 4: Hidden Window Is Visible (Shows 1px in Corner)

**What goes wrong:** The 1x1 hidden window appears as a tiny artifact in the top-left corner of the screen.

**Why it happens:** `Window` scenes without explicit positioning may appear at a default location. Without `.windowResizability(.contentSize)` and `.defaultSize(width: 1, height: 1)`, the window may be larger.

**How to avoid:** Apply `.windowResizability(.contentSize)` and `.defaultSize(width: 1, height: 1)` on the hidden Window scene. Also hide the window on launch in `AppDelegate.applicationDidFinishLaunching`:

```swift
// Hide the hidden helper window immediately after launch
DispatchQueue.main.async {
    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "hidden-settings-bridge" }) {
        window.orderOut(nil)
    }
}
```

**Warning signs:** Tiny pixel in the corner; window appears in Mission Control.

---

### Pitfall 5: SMAppService register() Throws in Development Builds

**What goes wrong:** `SMAppService.mainApp.register()` throws an error during development (swift build / swift run), even though it works in a distribution build.

**Why it happens:** SMAppService uses the app bundle identifier to identify the login item. SPM executables built with `swift build` may not have a properly formed app bundle with Info.plist in the expected location. The system cannot match the executable to a bundle identity.

**How to avoid:** Test SMAppService functionality with a properly wrapped app bundle (e.g., create a `.app` wrapper using the swift build output). Alternatively, wrap the register/unregister in a conditional:
```swift
#if DEBUG
// Skip registration in development; show a note in Settings
#else
try SMAppService.mainApp.register()
#endif
```

**Warning signs:** `register()` fails with an error code; `.status` returns `.notFound` instead of `.notRegistered`.

---

### Pitfall 6: Panel Stuck at alphaValue 0 After Interrupted Animation

**What goes wrong:** If the user rapidly toggles the panel (open/close/open in quick succession), the panel may get stuck invisible because `alphaValue` was animated to 0 but `orderOut` was called before the animation completed, and then `orderFrontRegardless` is called with `alphaValue` still at 0.

**Why it happens:** `NSAnimationContext` animations run asynchronously. Calling `hide()` during a show animation (or `show()` during a hide animation) can leave `alphaValue` in an inconsistent state.

**How to avoid:** Reset `alphaValue = 1.0` at the start of `show()` (cancel any in-flight fade-out), and track animation state with a Bool. Or use the simpler `animationBehavior = .utilityWindow` approach which does not require manual alpha management.

**Warning signs:** Panel icon click has no visible effect; panel exists but is invisible (can be typed into if focused).

---

## Code Examples

Verified patterns from official sources and authoritative community documentation:

### Defaults Key Extension (Phase 3 Preferences)

```swift
// Source: sindresorhus/Defaults README, version 9.0.6
import Defaults

// Define keys in one place — type-safe, defaults co-located
extension Defaults.Keys {
    // Example: if adding a "show completed tasks" preference in Phase 3
    // static let showCompletedTasks = Key<Bool>("showCompletedTasks", default: true)
    //
    // Launch-at-login is NOT stored here — always use SMAppService.mainApp.status
}
```

### @Default in SwiftUI View

```swift
// Source: sindresorhus/Defaults README
import Defaults

struct SettingsView: View {
    // @Default works directly in View structs
    // @Default(.showCompletedTasks) var showCompletedTasks

    var body: some View {
        // Toggle("Show completed tasks", isOn: $showCompletedTasks)
    }
}
```

**Note:** `@Default` is for SwiftUI views only. For `@Observable` classes (if needed), the `@ObservableDefault` macro was merged in Defaults 9.x (PR #189, November 2024). But for Phase 3, `@Default` in the `SettingsView` (a struct View) is correct and sufficient.

### ContentUnavailableView Empty State

```swift
// Source: Apple SwiftUI docs — ContentUnavailableView, macOS 14+
struct TaskListView: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        List(store.tasks) { task in
            TaskRowView(task: task)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .overlay {
            if store.tasks.isEmpty {
                ContentUnavailableView(
                    "All clear.",
                    systemImage: "checkmark.circle",
                    description: Text("Add a task to get started.")
                )
            }
        }
    }
}
```

### NSStatusItem with Both Click Types

```swift
// Source: Jesse Squires "Implementing right-click for NSButton" (verified community pattern)
import AppKit

extension NSEvent {
    var isRightClick: Bool {
        type == .rightMouseDown || modifierFlags.contains(.control)
    }
}

// Setup in applicationDidFinishLaunching:
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
if let button = statusItem.button {
    let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "QuickTask")
    image?.isTemplate = true
    button.image = image
    button.action = #selector(handleStatusItemClick)
    button.target = self
    button.sendAction(on: [.leftMouseDown, .rightMouseDown])
}

@objc private func handleStatusItemClick() {
    guard let event = NSApp.currentEvent else { return }
    if event.isRightClick {
        showContextMenu()
    } else {
        PanelManager.shared.toggle()
    }
}

private func showContextMenu() {
    let menu = NSMenu()
    let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
    settingsItem.target = self
    menu.addItem(settingsItem)
    menu.addItem(.separator())
    let quitItem = NSMenuItem(title: "Quit QuickTask", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    menu.addItem(quitItem)
    statusItem.button?.window?.perform(#selector(NSWindow.makeKeyAndOrderFront(_:)), with: nil)
    if let button = statusItem.button, let window = button.window {
        let buttonFrame = button.convert(button.bounds, to: nil)
        menu.popUp(positioning: nil, at: NSPoint(x: buttonFrame.minX, y: buttonFrame.minY), in: window)
    }
}
```

### FloatingPanel Animation Setup

```swift
// Source: Apple NSWindow.animationBehavior docs
// In FloatingPanel.init(), add one line:
self.animationBehavior = .utilityWindow
// PanelManager continues to use orderFrontRegardless() and orderOut(nil) normally
// macOS applies a subtle fade animation automatically
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `SMLoginItemSetEnabled` | `SMAppService.mainApp.register()` | macOS 13 (2022) | No helper app needed; cleaner API; user approval required via System Settings |
| `NSApp.sendAction(#selector(showPreferencesWindow:))` | Hidden `Window` scene + `@Environment(\.openSettings)` | macOS 14 broke old approach | Requires indirect notification bridge; activation policy juggling |
| Custom empty state `Text` view | `ContentUnavailableView` | macOS 14 (WWDC 2023) | Native component; HIG-compliant layout; no custom code |
| `SMJobBless` / helper apps for login items | `SMAppService.mainApp` | macOS 13 | Massive complexity reduction |

**Deprecated/outdated:**
- `SMLoginItemSetEnabled`: Deprecated. Still compiles but should not be used.
- `NSApp.sendAction(#selector(showPreferencesWindow:))` or `showSettingsWindow:`: Removed/broken in macOS 14 SwiftUI Settings scenes.
- `LSUIElement` in Info.plist (for SPM executables): Unreliable — use `NSApp.setActivationPolicy(.accessory)` at runtime (already established in Phase 1).

---

## Open Questions

1. **Hidden window ordering — NSPanel interaction**
   - What we know: The hidden `Window` scene workaround was primarily documented for `MenuBarExtra`-based apps. This app uses `NSStatusItem` + `NSPanel` (not `MenuBarExtra`). The pattern should still work because it only requires the SwiftUI `App` body to declare scenes correctly — it doesn't depend on `MenuBarExtra`.
   - What's unclear: Whether the timing (100ms, 200ms) is reliable on the app's specific `NSPanel` + `NSStatusItem` setup, or if any interaction with `FloatingPanel`'s activation policy creates edge cases.
   - Recommendation: Implement the hidden window pattern first. If Settings windows reliably fail, fall back to the manual `NSWindow` approach in `AppDelegate` (simpler, no timing dependencies).

2. **SMAppService behavior in SPM executables without a full .app bundle**
   - What we know: SMAppService uses bundle identity. SPM executables built with `swift build` may lack a proper bundle structure.
   - What's unclear: Whether `swift build -c release` output from this project, when run as an executable (not wrapped in .app), satisfies SMAppService's bundle requirements.
   - Recommendation: Include a `#if DEBUG` guard or a clear note in the Settings UI that launch-at-login requires an installed app bundle. The planner should add a manual verification step for this specific behavior.

3. **Panel animation and `.nonactivatingPanel` interaction**
   - What we know: `animationBehavior = .utilityWindow` should work on any NSWindow subclass including NSPanel. The `.nonactivatingPanel` style mask is orthogonal to animation.
   - What's unclear: Whether `orderFrontRegardless()` (required for `.accessory` apps) plays well with `animationBehavior` animations — `orderFrontRegardless` may bypass the animation.
   - Recommendation: Test both `orderFront(nil)` and `orderFrontRegardless()` with `.utilityWindow` animation behavior. If `orderFrontRegardless()` bypasses animation, use the manual `NSAnimationContext` approach (Approach B in Pattern 6).

---

## Sources

### Primary (HIGH confidence)
- Apple ServiceManagement framework — `SMAppService.mainApp`, `.status`, `.register()`, `.unregister()`, `Status` enum cases: https://developer.apple.com/documentation/servicemanagement/smappservice
- Apple SwiftUI docs — `ContentUnavailableView` (`@available(macOS 14.0, *)`): https://developer.apple.com/documentation/swiftui/contentunavailableview
- Apple AppKit docs — `NSWindow.animationBehavior`, `.AnimationBehavior.utilityWindow`: https://developer.apple.com/documentation/appkit/nswindow/animationbehavior-swift.enum
- Apple AppKit docs — `NSStatusItem`, `NSStatusBarButton`, `sendAction(on:)`: https://developer.apple.com/documentation/appkit/nsstatusitem
- sindresorhus/Defaults v9.0.6 README — `Defaults.Keys`, `Defaults[.key]`, `@Default` in View, `@ObservableDefault` in @Observable: https://github.com/sindresorhus/Defaults
- Apple openSettings environment value docs — `@Environment(\.openSettings)` requires macOS 14+: https://developer.apple.com/documentation/swiftui/environmentvalues/opensettings

### Secondary (MEDIUM confidence)
- Peter Steinberger "Showing Settings from macOS Menu Bar Items: A 5-Hour Journey" (June 2025) — Hidden window workaround, activation policy sequence, timing delays: https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items
- nilcoalescing.com "Add launch at login setting to a macOS app" — SMAppService register/unregister pattern, re-sync on window focus: https://nilcoalescing.com/blog/LaunchAtLoginSetting/
- Jesse Squires "Implementing right-click for NSButton" (2019, still valid) — `sendAction(on:)`, `NSApp.currentEvent`, `isRightClick` extension: https://www.jessesquires.com/blog/2019/08/15/implementing-right-click-for-nsbutton/
- orchetect/SettingsAccess Discussion #5 — `NSApp.sendAction` broken on macOS 14+; URL scheme alternative: https://github.com/orchetect/SettingsAccess/discussions/5
- sindresorhus/Defaults Issue #142 / PR #189 — `@ObservableDefault` macro merged November 2024 for @Observable class support: https://github.com/sindresorhus/Defaults/issues/142

### Tertiary (LOW confidence — validate before implementing)
- Apple Developer Forums thread 739831 — NSWindow created manually in AppDelegate as simpler fallback for Settings: https://developer.apple.com/forums/thread/739831
- Community consensus (multiple sources) — `SMAppService` may fail in SPM development builds without app bundle; behavior unverified for this project's exact build setup
- Apple Developer Forums (SMAppService) — `requiresApproval` behavior on first registration in non-sandboxed apps

---

## Metadata

**Confidence breakdown:**
- SMAppService API (register/unregister/status): HIGH — Apple-documented, stable since macOS 13
- Settings window workaround (hidden Window scene): MEDIUM — Community-validated (Peter Steinberger), aligns with SwiftUI docs, but timing delays are empirical
- NSStatusItem right-click pattern: HIGH — Documented AppKit API; Jesse Squires's approach well-known
- ContentUnavailableView: HIGH — Apple-documented, macOS 14+ confirmed
- Panel animation via animationBehavior: MEDIUM — API is documented; interaction with orderFrontRegardless needs runtime verification
- Defaults @Default in View: HIGH — README example, 9.0.6 current

**Research date:** 2026-02-17
**Valid until:** 2026-08-17 (stable Apple frameworks; 6-month estimate; the Settings window workaround is tied to OS behavior and may change with macOS updates)
