---
phase: 03-settings-launch-at-login-v1-polish
verified: 2026-02-17T00:00:00Z
status: human_needed
score: 10/10 must-haves verified
re_verification: false
human_verification:
  - test: "Right-click menu bar icon and confirm context menu appears with 'Settings...' and 'Quit QuickTask' items"
    expected: "A native NSMenu drops down anchored to the status item button, not attached to the menu bar itself"
    why_human: "NSMenu.popUp(positioning:at:in:) behavior and positioning cannot be verified statically"
  - test: "Select 'Settings...' from the context menu and confirm the Settings window opens"
    expected: "A macOS Settings window containing a 'Launch at Login' toggle under a 'General' section header appears within 200ms"
    why_human: "NotificationCenter -> HiddenWindowView -> openSettings() activation policy juggle requires runtime macOS session"
  - test: "Left-click the menu bar icon and confirm the floating panel still toggles (no regression)"
    expected: "The panel opens on left-click and closes on a second left-click; right-click does not toggle the panel"
    why_human: "sendAction(on: [.leftMouseDown, .rightMouseDown]) + currentEvent routing cannot be exercised without a running NSApplication"
  - test: "With no tasks, open the panel and confirm the empty state is visible"
    expected: "A centered 'All clear.' label with a checkmark circle icon and 'Add a task to get started.' description appears"
    why_human: "ContentUnavailableView rendering and centering within the List overlay requires visual confirmation"
  - test: "Open and close the floating panel and confirm the animation feels smooth"
    expected: "The panel fades in and out rather than snapping; no jarring instant appearance or disappearance"
    why_human: "animationBehavior = .utilityWindow effect on orderFrontRegardless() depends on macOS window server; cannot verify without running app"
  - test: "Enable 'Launch at Login' in Settings (release build or with bundle), reboot, and confirm the app starts automatically"
    expected: "QuickTask appears in the menu bar after login without user action"
    why_human: "SMAppService.mainApp.register() requires a properly bundled .app with matching bundle ID; DEBUG guard deliberately skips this in dev builds"
---

# Phase 3: Settings, Launch at Login, and v1 Polish — Verification Report

**Phase Goal:** A complete v1 that feels finished — opt-in launch at login so the app survives reboots, a Settings window accessible from the menu bar, an encouraging empty state, and smooth animations that make every interaction feel deliberate.

**Verified:** 2026-02-17
**Status:** human_needed — all automated checks passed; 6 items require runtime macOS verification
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                   | Status     | Evidence                                                                                  |
|----|-----------------------------------------------------------------------------------------|------------|-------------------------------------------------------------------------------------------|
| 1  | Right-clicking the menu bar icon shows a context menu with Settings... and Quit QuickTask | VERIFIED   | `sendAction(on: [.leftMouseDown, .rightMouseDown])` + `showContextMenu()` in AppDelegate  |
| 2  | Left-clicking the menu bar icon still toggles the floating panel                        | VERIFIED   | `handleStatusItemClick()` calls `PanelManager.shared.toggle()` on left-click path         |
| 3  | Selecting Settings... from the context menu opens a Settings window                     | VERIFIED   | `openSettingsFromMenu()` posts `.openSettingsRequest`; `HiddenWindowView.onReceive` calls `openSettings()` |
| 4  | Settings window contains a Launch at Login toggle that defaults to off                  | VERIFIED   | `@State private var launchAtLogin = false`; `.onAppear` sets from `SMAppService.mainApp.status == .enabled` |
| 5  | Toggling Launch at Login calls SMAppService.mainApp.register() or .unregister()         | VERIFIED   | `handleLaunchAtLoginChange(_:)` in SettingsView.swift; DEBUG guard in place for dev builds |
| 6  | Launch at Login state is read from SMAppService.mainApp.status at runtime               | VERIFIED   | No `Defaults[` or `@Default` for launch-at-login state; `.onAppear` queries `.status`     |
| 7  | Menu bar icon uses a template image for correct light/dark tinting                      | VERIFIED   | `image.isTemplate = true` explicitly set in `setupStatusItem()` before `button.image = image` |
| 8  | An empty task list shows an encouraging placeholder instead of blank space              | VERIFIED   | `.overlay { if store.tasks.isEmpty { ContentUnavailableView("All clear.", ...) } }` in TaskListView |
| 9  | The panel opens with a smooth animation                                                 | VERIFIED*  | `animationBehavior = .utilityWindow` in `FloatingPanel.init()`; runtime confirmation needed |
| 10 | The panel closes with a smooth animation                                                | VERIFIED*  | Same `animationBehavior` applies to `orderOut` calls; runtime confirmation needed          |

*Static code verification passed. Runtime behavior requires human confirmation on macOS.

**Score:** 10/10 truths verified statically

---

## Required Artifacts

### Plan 01 Artifacts

| Artifact                                              | Provides                                          | Status     | Details                                                                           |
|-------------------------------------------------------|---------------------------------------------------|------------|-----------------------------------------------------------------------------------|
| `QuickTask/Sources/Settings/SettingsView.swift`       | Settings UI with Launch at Login toggle           | VERIFIED   | Exists, 50 lines, contains `SMAppService.mainApp` (status, register, unregister) |
| `QuickTask/Sources/App/QuickTaskApp.swift`            | Hidden Window scene before Settings scene         | VERIFIED   | Exists, `Window("", id: "hidden-settings-bridge")` declared on line 46, before `Settings {` on line 54 |
| `QuickTask/Sources/App/AppDelegate.swift`             | Right-click context menu, notification post, template image | VERIFIED | Exists, 127 lines, contains `sendAction(on:`, `showContextMenu`, `openSettingsRequest`, `isTemplate = true` |
| `QuickTask/Package.swift`                             | Defaults SPM dependency                           | VERIFIED   | Contains `.package(url: "https://github.com/sindresorhus/Defaults", from: "9.0.0")` and `"Defaults"` in target deps |

### Plan 02 Artifacts

| Artifact                                              | Provides                                          | Status     | Details                                                                           |
|-------------------------------------------------------|---------------------------------------------------|------------|-----------------------------------------------------------------------------------|
| `QuickTask/Sources/Views/TaskListView.swift`          | Empty state overlay when no tasks exist           | VERIFIED   | Contains `ContentUnavailableView`, `store.tasks.isEmpty`, `"All clear."`, `"checkmark.circle"` |
| `QuickTask/Sources/Panel/FloatingPanel.swift`         | Animation behavior configuration                  | VERIFIED   | Contains `animationBehavior = .utilityWindow` after `hasShadow = true` in init   |
| `QuickTask/Sources/Panel/PanelManager.swift`          | alphaValue safety reset before show               | VERIFIED   | Contains `panel.alphaValue = 1.0` before `panel.orderFrontRegardless()` in `show()` |

---

## Key Link Verification

| From                                          | To                                        | Via                                                  | Status     | Details                                                                                  |
|-----------------------------------------------|-------------------------------------------|------------------------------------------------------|------------|------------------------------------------------------------------------------------------|
| `AppDelegate.swift`                           | `QuickTaskApp.swift` (HiddenWindowView)   | `NotificationCenter.post(.openSettingsRequest)`       | WIRED      | `openSettingsFromMenu()` posts; `HiddenWindowView.onReceive(.openSettingsRequest)` receives |
| `QuickTaskApp.swift` (HiddenWindowView)       | Settings scene                            | `@Environment(\.openSettings)` + `openSettings()`    | WIRED      | `@Environment(\.openSettings) private var openSettings` declared; called in Task block   |
| `SettingsView.swift`                          | ServiceManagement framework               | `SMAppService.mainApp.register/unregister/status`    | WIRED      | All three access paths present: `.status` in `.onAppear`, `.register()` and `.unregister()` in handler |
| `TaskListView.swift`                          | `TaskStore.swift`                         | `store.tasks.isEmpty` check for overlay              | WIRED      | `@Environment(TaskStore.self) private var store`; `store.tasks.isEmpty` in overlay condition |
| `FloatingPanel.swift` `animationBehavior`     | PanelManager show/hide calls              | `animationBehavior` applied in `init()` before any orderFront/orderOut | WIRED | Set in `FloatingPanel.init()`; `PanelManager` calls `orderFrontRegardless()` and `panel?.orderOut(nil)` |

### Critical Negative Check

| Check                                          | Expected    | Actual      | Status |
|------------------------------------------------|-------------|-------------|--------|
| `statusItem.menu =` assignment in AppDelegate  | ABSENT      | Not found   | PASS   |
| `Defaults[` or `@Default` for launch-at-login  | ABSENT      | Not found   | PASS   |

---

## Requirements Coverage

| Requirement | Source Plan | Description                                       | Status    | Evidence                                                             |
|-------------|-------------|---------------------------------------------------|-----------|----------------------------------------------------------------------|
| SETT-01     | 03-01-PLAN  | Launch at login toggle (opt-in, defaults to off)  | SATISFIED | `SettingsView.swift`: `@State private var launchAtLogin = false`; `.onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }`; `handleLaunchAtLoginChange` calls `register()`/`unregister()` |
| SETT-02     | 03-01-PLAN  | Settings accessible from menu bar icon context menu | SATISFIED | `AppDelegate.swift`: `handleStatusItemClick()` calls `showContextMenu()` on right-click; menu contains `"Settings..."` item that posts `.openSettingsRequest`; notification bridge opens the Settings scene |

**Orphaned requirements check:** Plan 03-02 declares `requirements: []`. REQUIREMENTS.md maps only SETT-01 and SETT-02 to Phase 3. No orphaned requirements exist.

**Coverage: 2/2 Phase 3 requirements satisfied.**

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `QuickTask/Sources/Views/TaskListView.swift` | 10 | "placeholder" appears in doc comment | Info | Not a code placeholder — the comment describes the ContentUnavailableView component as an "encouraging placeholder"; actual implementation is substantive |

No blockers or warnings found.

---

## Human Verification Required

### 1. Right-Click Context Menu Appearance

**Test:** Right-click the QuickTask menu bar icon (or Ctrl+click it)
**Expected:** A native macOS context menu appears anchored below the status item, showing "Settings..." (Cmd+,) and a separator, then "Quit QuickTask" (Cmd+Q)
**Why human:** NSMenu.popUp(positioning:at:in:) positioning relative to the status item button can only be verified visually in a running macOS session

### 2. Settings Window Opens from Menu

**Test:** Right-click the menu bar icon, select "Settings..."
**Expected:** A Settings window titled "QuickTask" (or the app name) appears within ~300ms containing a "General" section with a "Launch at Login" toggle; the floating panel does NOT open
**Why human:** The NotificationCenter bridge involves activation policy juggling (.regular -> .accessory); the timing and window ordering require a real macOS window server

### 3. Left-Click Panel Toggle Not Regressed

**Test:** Left-click the menu bar icon; left-click again to close
**Expected:** The floating panel opens on the first left-click and closes on the second; right-clicking does not trigger the panel
**Why human:** The sendAction(on: [.leftMouseDown, .rightMouseDown]) + NSApp.currentEvent routing requires a live NSApplication run loop

### 4. Empty State Visual Appearance

**Test:** Open the floating panel with no tasks in the list
**Expected:** A centered "All clear." heading with a checkmark circle icon above it and "Add a task to get started." subtitle below it; the layout follows HIG conventions with appropriate spacing
**Why human:** ContentUnavailableView centering and icon rendering within a List overlay requires visual confirmation

### 5. Panel Animation Feel

**Test:** Trigger the panel open (hotkey or menu bar click) and close it (Escape key or click outside) several times in rapid succession
**Expected:** Each open/close transitions with a subtle native macOS fade rather than snapping instantly; rapid toggling does not leave the panel invisible
**Why human:** animationBehavior = .utilityWindow effect depends on macOS window server; whether orderFrontRegardless() respects this behavior (noted as an open question in research) cannot be determined statically

### 6. Launch at Login (Release Build Only)

**Test:** Build a properly bundled .app, enable "Launch at Login" in Settings, log out and log back in
**Expected:** QuickTask appears in the menu bar without any user action; the Launch at Login toggle shows as enabled when Settings is reopened
**Why human:** SMAppService.mainApp.register() requires a code-signed .app bundle with matching bundle ID; the DEBUG guard intentionally skips this in development builds; runtime macOS login item registration cannot be verified statically

---

## Commit Verification

All four task commits documented in the SUMMARYs were verified present in the git log:

| Commit   | Plan  | Description                                                     |
|----------|-------|-----------------------------------------------------------------|
| `7527a6e` | 03-01 | feat: add SettingsView, Defaults dep, hidden Window scene, panel animation |
| `cf68fe4` | 03-01 | feat: add right-click context menu and template image to NSStatusItem |
| `dce3c7e` | 03-02 | feat: add ContentUnavailableView empty state overlay to TaskListView |
| `e24d5c0` | 03-02 | feat: add smooth panel open/close animation via animationBehavior |

---

## Summary

All 10 observable truths pass static verification. All 7 artifacts exist, are substantive (not stubs), and are correctly wired. Both SETT-01 and SETT-02 requirements are satisfied with real implementation. No banned patterns (statusItem.menu assignment, Defaults-stored launch-at-login state, empty handlers, placeholder returns) were found.

Phase 3 goal achievement is blocked only by the inherent constraint that this is a macOS GUI application developed in a Linux environment — 6 behaviors require runtime confirmation on macOS hardware. The code is structurally complete.

The most important runtime check is item 5 (animation feel via orderFrontRegardless) — research flagged this as an open question since orderFrontRegardless may bypass animationBehavior. If the fade does not appear, the fallback (instant show/hide) is still functionally correct and was noted as acceptable for v1 in the plan.

---

_Verified: 2026-02-17_
_Verifier: Claude (gsd-verifier)_
