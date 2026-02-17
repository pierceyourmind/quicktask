---
phase: 01-app-shell-hotkey-floating-panel
verified: 2026-02-17T00:00:00Z
status: human_needed
score: 5/5 must-haves verified
re_verification: false
human_verification:
  - test: "Build and run on macOS: swift build && swift run QuickTask. Verify the checkmark.circle icon appears in the macOS status bar."
    expected: "Menu bar icon visible at all times in the macOS status bar."
    why_human: "Cannot compile or execute Swift on Linux. NSStatusItem visibility can only be confirmed at runtime on macOS."
  - test: "After launching, confirm QuickTask is NOT visible in the Dock. Check Activity Monitor to confirm the process is running."
    expected: "No Dock icon. Process appears in Activity Monitor."
    why_human: "NSApp.setActivationPolicy(.accessory) and LSUIElement effect can only be observed at macOS runtime."
  - test: "Click the menu bar icon. Verify a floating panel appears centered on screen, slightly above vertical center (Spotlight-style), floating above all other windows."
    expected: "Panel appears centered, Spotlight-style, above other windows."
    why_human: "Panel positioning and window level require macOS runtime. Cannot verify frame coordinates visually without running the app."
  - test: "With the panel open, press Escape. Verify the panel closes."
    expected: "Panel closes on Escape. Previous app regains focus."
    why_human: "Key event handling (keyCode 53) and focus-return require runtime verification."
  - test: "Open the panel. Click anywhere outside it (another app window or the Desktop). Verify the panel closes."
    expected: "Panel closes. The app you clicked regains focus."
    why_human: "NSEvent.addGlobalMonitorForEvents behavior depends on macOS accessibility/input monitoring permissions granted at runtime."
  - test: "Switch to another app (e.g., Finder, Terminal). Press Cmd+Shift+Space. Verify the panel opens even though QuickTask is not the active app."
    expected: "Panel opens from background. Hotkey fires from any app."
    why_human: "KeyboardShortcuts global hotkey registration (via CGEventTap/Carbon) requires macOS runtime and Input Monitoring permission grant."
  - test: "Press Cmd+Shift+Space repeatedly (open/close). Verify the toggle works bidirectionally with no perceptible delay."
    expected: "Toggle is near-instant (<200ms perceived latency). No crashes from rapid toggling."
    why_human: "Latency and idempotency under rapid toggling require runtime verification."
  - test: "Open Terminal, type something. Press Cmd+Shift+Space (panel opens). Press Escape (panel closes). Verify the cursor is back in Terminal without needing to click."
    expected: "Focus returns to the previously active app automatically after any dismissal path."
    why_human: "previousApp?.activate(options: []) focus-return behavior can only be verified by observing window focus at macOS runtime."
---

# Phase 1: App Shell, Hotkey, and Floating Panel — Verification Report

**Phase Goal:** A running macOS app with a persistent menu bar icon, a floating panel that opens and closes on a global hotkey, and correct dismissal behavior — with all six critical architectural pitfalls resolved before any UI or data work begins.

**Verified:** 2026-02-17
**Status:** human_needed
**Re-verification:** No — initial verification

## Summary

All source code artifacts are present, substantive, and correctly wired. Every pattern required by the PLANs' `must_haves` is confirmed in the actual source files. The 9 phase requirements (SHELL-01 through SHELL-05, HKEY-01 through HKEY-04) are implemented at the code level with no stubs or missing links.

The status is `human_needed` — not `gaps_found` — because all automated checks pass. The outstanding items are behavioral runtime verifications that cannot be performed without a macOS Swift toolchain, which is unavailable in this Linux development environment. This constraint was anticipated by all three PLANs and documented in all three SUMMARYs.

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Menu bar icon visible at all times; clicking it opens and closes the panel | ? HUMAN NEEDED | `NSStatusItem` declared as `private var statusItem: NSStatusItem!` on AppDelegate (line 16). `setupStatusItem()` creates it with `NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)` and wires `#selector(togglePanel)` -> `PanelManager.shared.toggle()`. Strong instance property retention verified. Runtime visibility requires macOS. |
| 2 | Pressing global hotkey (Cmd+Shift+Space) opens panel from any app, even when QuickTask has no focus | ? HUMAN NEEDED | `HotkeyService.register()` calls `KeyboardShortcuts.onKeyUp(for: .togglePanel)` with default `.init(.space, modifiers: [.command, .shift])`. Called from `applicationDidFinishLaunching`. Correct library (KeyboardShortcuts SPM, not SwiftUI .keyboardShortcut()). Runtime registration requires macOS + Input Monitoring permission. |
| 3 | Panel appears within 200ms perceived latency, centered on screen, Spotlight-style | ? HUMAN NEEDED | Panel is created lazily (`lazy var panel`) — pre-created on first `show()`, only `orderFrontRegardless()` needed on subsequent shows. Positioning: `x = screenFrame.midX - 200`, `y = screenFrame.midY + screenFrame.height * 0.1`. Latency requires runtime measurement. |
| 4 | Pressing Escape or clicking outside the panel closes it | ? HUMAN NEEDED | Escape: `FloatingPanel.keyDown` checks `event.keyCode == 53` -> `PanelManager.shared.hide()`. Click-outside: `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])` installed in `show()`, removed in `hide()`. `resignKey()` override provides additional fallback. All paths call idempotent `hide()` with `guard isVisible`. Runtime behavior requires macOS. |
| 5 | After dismissal, keyboard focus returns to previously active app (not QuickTask) | ? HUMAN NEEDED | `previousApp = NSWorkspace.shared.frontmostApplication` captured in `show()` before panel appears. `previousApp?.activate(options: [])` called in `hide()` then cleared. Pattern confirmed at lines 58 and 116-117 of PanelManager.swift. Focus-return requires macOS runtime to observe. |

**Score:** 5/5 truths — all architecturally verified; all require macOS runtime confirmation for behavioral verification.

---

## Required Artifacts

### Plan 01-01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `QuickTask/Package.swift` | SPM executable package with macOS 14 target, KeyboardShortcuts and Defaults dependencies | VERIFIED | Contains `PackageDescription`, `.macOS(.v14)`, both dependencies from `"2.4.0"` / `"9.0.0"`, `executableTarget`, `swift-tools-version: 5.10`. 22 lines. |
| `QuickTask/Sources/App/QuickTaskApp.swift` | @main app entry point with AppDelegate adapter | VERIFIED | Contains `@main`, `@NSApplicationDelegateAdaptor(AppDelegate.self)`, `Settings { EmptyView() }` scene body. 15 lines. |
| `QuickTask/Sources/App/AppDelegate.swift` | AppDelegate class with applicationDidFinishLaunching | VERIFIED | `class AppDelegate: NSObject, NSApplicationDelegate`, `applicationDidFinishLaunching`, `NSApp.setActivationPolicy(.accessory)`. 49 lines. |
| `QuickTask/Sources/Info.plist` | LSUIElement = YES to suppress Dock icon | VERIFIED | `<key>LSUIElement</key><true/>` present at line 22. Also contains `CFBundleIdentifier`, `CFBundleName`, `NSAccessibilityUsageDescription`. |

### Plan 01-02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `QuickTask/Sources/Panel/FloatingPanel.swift` | NSPanel subclass with non-activating floating behavior | VERIFIED | `class FloatingPanel<Content: View>: NSPanel`, 96 lines (min_lines: 30 requirement exceeded). Contains `.nonactivatingPanel`, `.floating` level, `canBecomeKey: Bool { true }`, `canBecomeMain: Bool { false }`, `isReleasedWhenClosed = false`, `hidesOnDeactivate = false`, `NSHostingView(rootView: rootView)`. |
| `QuickTask/Sources/Panel/PanelManager.swift` | Singleton managing panel show/hide/toggle and screen positioning | VERIFIED | `final class PanelManager`, `static let shared`, `lazy var panel`, `toggle()`, `show()`, `hide()`. Spotlight positioning implemented. 119 lines. |
| `QuickTask/Sources/App/AppDelegate.swift` | NSStatusItem strong reference and menu bar icon click handler | VERIFIED | `private var statusItem: NSStatusItem!` instance property. `setupStatusItem()` creates and configures it. `@objc private func togglePanel()` calls `PanelManager.shared.toggle()`. |

### Plan 01-03 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `QuickTask/Sources/Hotkey/HotkeyService.swift` | Global hotkey registration using KeyboardShortcuts library | VERIFIED | `import KeyboardShortcuts`, `extension KeyboardShortcuts.Name` with `.togglePanel`, `final class HotkeyService`, `static let shared`, `func register()` with `onKeyUp(for: .togglePanel)`. 37 lines (min_lines: 15 exceeded). |
| `QuickTask/Sources/Panel/FloatingPanel.swift` | resignKey override for focus-return and Escape key handling | VERIFIED | `override func resignKey()` at line 90 calls `PanelManager.shared.hide()`. `override func keyDown(with:)` checks `keyCode == 53` at line 77. Both present. |
| `QuickTask/Sources/Panel/PanelManager.swift` | Focus-return logic storing previous app, click-outside monitor | VERIFIED | `private var previousApp: NSRunningApplication?` at line 36. `private var clickMonitor: Any?` at line 40. `NSWorkspace.shared.frontmostApplication` captured in `show()`. `activate(options: [])` called in `hide()`. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `QuickTaskApp.swift` | `AppDelegate.swift` | `@NSApplicationDelegateAdaptor` | WIRED | Pattern `@NSApplicationDelegateAdaptor(AppDelegate.self)` confirmed at line 5 of QuickTaskApp.swift. |
| `AppDelegate.swift` | `PanelManager.swift` | Status item button action calls `PanelManager.shared.toggle()` | WIRED | `button.action = #selector(togglePanel)` -> `@objc private func togglePanel()` -> `PanelManager.shared.toggle()` confirmed. |
| `PanelManager.swift` | `FloatingPanel.swift` | PanelManager owns FloatingPanel, calls `orderFront`/`orderOut` | WIRED | `private lazy var panel: FloatingPanel<ContentView>` owns the instance. `panel.orderFrontRegardless()`, `panel.makeKey()`, `panel.orderOut(nil)` all present. |
| `FloatingPanel.swift` | `ContentView.swift` | NSHostingView bridges SwiftUI ContentView into the panel | WIRED | `contentView = NSHostingView(rootView: rootView)` at line 62. PanelManager passes `ContentView()` as rootView. |
| `HotkeyService.swift` | `PanelManager.swift` | `KeyboardShortcuts.onKeyUp` triggers `PanelManager.shared.toggle()` | WIRED | `KeyboardShortcuts.onKeyUp(for: .togglePanel) { PanelManager.shared.toggle() }` confirmed at lines 33-35 of HotkeyService.swift. |
| `FloatingPanel.swift` | `PanelManager.swift` | `resignKey()` calls `PanelManager.shared.hide()` | WIRED | `override func resignKey()` at line 90 calls `PanelManager.shared.hide()` at line 93. |
| `PanelManager.swift` | `NSRunningApplication` | Stores and reactivates previous frontmost app on dismiss | WIRED | `NSWorkspace.shared.frontmostApplication` stored to `previousApp` at line 58. `previousApp?.activate(options: [])` at line 116. |
| `AppDelegate.swift` | `HotkeyService.swift` | `applicationDidFinishLaunching` calls `HotkeyService.shared.register()` | WIRED | `HotkeyService.shared.register()` at line 25 of AppDelegate.swift, inside `applicationDidFinishLaunching`. |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SHELL-01 | 01-02 | Menu bar icon visible in macOS status bar at all times | CODE VERIFIED / HUMAN NEEDED | `NSStatusItem` strongly retained on `AppDelegate` as `private var statusItem: NSStatusItem!`. Runtime visibility requires macOS. |
| SHELL-02 | 01-01 | App runs as menu bar agent (no Dock icon, LSUIElement) | CODE VERIFIED / HUMAN NEEDED | `NSApp.setActivationPolicy(.accessory)` in `applicationDidFinishLaunching`. `LSUIElement = YES` in Info.plist. Dock suppression requires macOS runtime. |
| SHELL-03 | 01-02 | Floating panel appears centered on screen (Spotlight-style) when activated | CODE VERIFIED / HUMAN NEEDED | Spotlight-style positioning in `PanelManager.show()`: `x = midX - 200`, `y = midY + height * 0.1`. Requires macOS to visually confirm. |
| SHELL-04 | 01-03 | Panel dismisses on Escape key press | CODE VERIFIED / HUMAN NEEDED | `FloatingPanel.keyDown` checks `event.keyCode == 53` -> `PanelManager.shared.hide()`. Requires macOS runtime. |
| SHELL-05 | 01-03 | Panel dismisses on click outside the panel | CODE VERIFIED / HUMAN NEEDED | `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])` in `show()`. Removed in `hide()`. Requires macOS + Input Monitoring permission. |
| HKEY-01 | 01-03 | Global keyboard shortcut toggles floating panel open/closed | CODE VERIFIED / HUMAN NEEDED | `KeyboardShortcuts.onKeyUp(for: .togglePanel)` -> `PanelManager.shared.toggle()`. Requires macOS runtime with Input Monitoring permission. |
| HKEY-02 | 01-03 | Hotkey works when app is in background (any app focused) | CODE VERIFIED / HUMAN NEEDED | `KeyboardShortcuts` library (not SwiftUI `.keyboardShortcut()`) is the correct API for background-capable global hotkeys. Requires macOS runtime from a different foreground app. |
| HKEY-03 | 01-03 | Panel appears in <200ms perceived latency on hotkey press | CODE VERIFIED / HUMAN NEEDED | Panel is lazily pre-created; `show()` only calls `orderFrontRegardless()` + `makeKey()`. No disk I/O or network on show path. Latency requires macOS runtime measurement. |
| HKEY-04 | 01-03 | Focus returns to previous app when panel is dismissed | CODE VERIFIED / HUMAN NEEDED | `previousApp` captured before show, `previousApp?.activate(options: [])` called in `hide()`. Covers all dismissal paths (Escape, click-outside, hotkey toggle, resignKey). Requires macOS runtime. |

**Coverage: 9/9 Phase 1 requirements claimed and implemented. 0 orphaned.**

No requirements mapped to Phase 1 in REQUIREMENTS.md are missing from any plan. No plan claims requirements outside the ROADMAP-specified set for Phase 1.

---

## Architectural Pitfall Compliance

The phase goal explicitly requires "all six critical architectural pitfalls resolved." Verification against ROADMAP.md constraints:

| Pitfall / Constraint | Required Pattern | Status | Evidence |
|----------------------|-----------------|--------|----------|
| Use NSStatusItem + custom NSPanel — NOT MenuBarExtra | No `MenuBarExtra` usage | VERIFIED | No `MenuBarExtra` anywhere in source. QuickTaskApp.swift uses `Settings { EmptyView() }`. Comments explicitly document this decision. |
| Panel uses `.nonactivatingPanel` + `canBecomeKey = true` + `panel.makeKey()` | All three present | VERIFIED | `.nonactivatingPanel` in styleMask (line 23 FloatingPanel). `canBecomeKey: Bool { true }` (line 68). `panel.makeKey()` in PanelManager.show() (line 80). |
| Override `resignKey()` on panel to return focus | `resignKey` override calling `PanelManager.shared.hide()` | VERIFIED | `override func resignKey()` at line 90 of FloatingPanel.swift. |
| NSStatusItem must be strongly retained on AppDelegate | Instance property, not local var | VERIFIED | `private var statusItem: NSStatusItem!` as instance property on AppDelegate (line 16). Not a local variable in `applicationDidFinishLaunching`. |
| Use KeyboardShortcuts SPM 2.4.0 for global hotkey — never SwiftUI.keyboardShortcut() | `import KeyboardShortcuts`, `onKeyUp` | VERIFIED | `from: "2.4.0"` in Package.swift. `KeyboardShortcuts.onKeyUp` in HotkeyService. No SwiftUI `.keyboardShortcut()` usage found. |
| LSUIElement = YES in Info.plist to suppress Dock icon | `<key>LSUIElement</key><true/>` in plist | VERIFIED | Present at line 21-22 of Info.plist. Runtime backup: `NSApp.setActivationPolicy(.accessory)`. |

All six architectural pitfalls from the ROADMAP are resolved in code.

---

## Anti-Patterns Found

| File | Pattern | Severity | Assessment |
|------|---------|----------|------------|
| `ContentView.swift` | Placeholder comment + stub body `Text("QuickTask")` | Info | INTENTIONAL. ContentView is explicitly designated as a Phase 1 placeholder per all three PLANs. Phase 2 will replace it with the task capture UI. This is not a gap — the goal for Phase 1 was the shell, hotkey, and panel, not the task UI. |

No blocker or warning-level anti-patterns found. No `TODO`/`FIXME` code stubs. No empty handler implementations. No `return null`/`return {}` API stubs. All implementations are substantive.

---

## Human Verification Required

All automated source-level checks have passed. The following 8 behavioral tests require a macOS machine with Swift toolchain to complete. All are verified at the code/architecture level; these tests confirm correct runtime behavior.

**Build command:** `cd /path/to/todo-app/QuickTask && swift build && swift run QuickTask`

### 1. Menu Bar Icon Visible (SHELL-01)

**Test:** Launch the app. Look at the macOS status bar (top-right of screen).
**Expected:** A checkmark.circle SF Symbol icon appears in the status bar and persists after switching to other apps.
**Why human:** NSStatusItem visibility can only be confirmed at macOS runtime.

### 2. No Dock Icon (SHELL-02)

**Test:** After launch, check the Dock and Activity Monitor.
**Expected:** QuickTask is NOT in the Dock. It IS in Activity Monitor.
**Why human:** `NSApp.setActivationPolicy(.accessory)` effect requires macOS runtime.

### 3. Floating Panel Positioning (SHELL-03)

**Test:** Click the menu bar icon.
**Expected:** A floating panel appears centered on screen, positioned slightly above vertical center (Spotlight-style). It floats above all other windows.
**Why human:** Window frame positioning and window level require macOS runtime.

### 4. Escape Dismissal (SHELL-04)

**Test:** Open the panel via menu bar click or hotkey. Press Escape.
**Expected:** Panel closes. The previously active app regains keyboard focus without requiring a click.
**Why human:** Key event delivery and focus-return require macOS runtime.

### 5. Click-Outside Dismissal (SHELL-05)

**Test:** Open the panel. Click anywhere outside it (another app window or the Desktop).
**Expected:** Panel closes. The app you clicked regains focus.
**Why human:** `NSEvent.addGlobalMonitorForEvents` requires macOS + Input Monitoring permission granted at runtime.

### 6. Global Hotkey from Any App (HKEY-01 + HKEY-02)

**Test:** Switch to a different app (Finder, Terminal, Safari). Press Cmd+Shift+Space.
**Expected:** The panel opens even though QuickTask is not the active app. Press Cmd+Shift+Space again — panel closes.
**Why human:** KeyboardShortcuts CGEventTap requires macOS + Input Monitoring permission; behavior depends on granted permission.

### 7. Hotkey Latency (HKEY-03)

**Test:** Press Cmd+Shift+Space repeatedly (open and close several times).
**Expected:** Panel appears near-instantly on each press. No perceptible delay (subjectively under 200ms). No crashes from rapid toggling.
**Why human:** Latency is a perceived runtime characteristic. Idempotency under rapid toggling requires live execution.

### 8. Focus Return to Previous App (HKEY-04)

**Test:** Set focus to Terminal and type something. Press Cmd+Shift+Space (panel opens). Press Escape (panel closes). Without clicking Terminal, try typing.
**Expected:** Your keystrokes appear in Terminal — focus returned automatically. Repeat from Finder to confirm the behavior is general.
**Why human:** `previousApp?.activate(options: [])` focus-return can only be observed by watching window focus at macOS runtime.

---

## Gaps Summary

No gaps. All source artifacts exist, are substantive, and are correctly wired. The phase goal is architecturally achieved. The remaining work is runtime verification on macOS, which was explicitly noted as a constraint in all three SUMMARYs and is the correct next action before Phase 2 begins.

---

_Verified: 2026-02-17_
_Verifier: Claude (gsd-verifier)_
