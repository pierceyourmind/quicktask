# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-17)

**Core value:** Zero-friction task capture — one hotkey and a few keystrokes saves a task before it vanishes
**Current focus:** Phase 2 complete — Phase 3 next (Polish and Settings)

## Current Position

Phase: 3 of 3 v1 phases (Settings, Launch at Login, v1 Polish) — IN PROGRESS
Plan: 2 of 2 in current phase — COMPLETE
Status: Phase 3 plan 2 complete; all v1 polish items done
Last activity: 2026-02-18 — Completed 03-02: ContentUnavailableView empty state + FloatingPanel animationBehavior smooth animation

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**
- Total plans completed: 8
- Average duration: ~3 min
- Total execution time: ~24 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-app-shell-hotkey-floating-panel | 3 | ~14 min | ~4 min |
| 02-task-data-model-persistence-capture-ui | 3 | ~4 min | ~1.3 min |
| 03-settings-launch-at-login-v1-polish | 2 | ~6 min | ~3 min |

**Recent Trend:** 6 plans completed

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Research]: Use NSStatusItem + NSPanel subclass — NOT MenuBarExtra(.window); cannot be programmatically toggled from a global hotkey
- [Research]: Use KeyboardShortcuts SPM 2.4.0 for the global hotkey — never SwiftUI .keyboardShortcut() (does not fire when backgrounded)
- [Research]: JSON + FileManager for task persistence — no Core Data, no database server
- [Research]: Swift 6.1 with @Observable (macOS 14+) — Combine not needed
- [01-01]: swift-tools-version 5.10 over 6.0 — avoids strict concurrency errors before MainActor annotations are in place
- [01-01]: Runtime NSApp.setActivationPolicy(.accessory) over Info.plist LSUIElement alone — SPM executables may not auto-apply plist key
- [01-01]: Settings { EmptyView() } as SwiftUI App body — real UI is NSPanel managed by AppDelegate (Plan 02)
- [01-02]: FloatingPanel uses .nonactivatingPanel + canBecomeKey=true — both required for text input without focus steal
- [01-02]: isReleasedWhenClosed=false on FloatingPanel — prevents ARC crash on repeated show/hide toggle
- [01-02]: orderFrontRegardless()+makeKey() instead of makeKeyAndOrderFront — avoids full app activation for .accessory apps
- [01-02]: NSStatusItem as private var on AppDelegate instance — strong reference prevents ARC deallocation (menu icon vanish bug)
- [01-03]: KeyboardShortcuts.onKeyUp (not onKeyDown) for toggle hotkey — avoids repeated fires on key-hold
- [01-03]: NSEvent.addGlobalMonitorForEvents (not local) — must detect clicks in other apps' windows for click-outside
- [01-03]: activate(options: []) (empty, not .activateIgnoringOtherApps) — gentle reactivation sufficient when panel is already hidden
- [01-03]: Both click monitor AND resignKey() dismiss paths kept — redundant by design; resignKey() may not fire in all macOS configurations
- [02-01]: AnyView wrapper for FloatingPanel<AnyView>? stored property — FloatingPanel<some View> is invalid as stored property type in Swift
- [02-01]: configure(with:) pattern not singleton TaskStore — TaskStore created in AppDelegate, passed to PanelManager for explicit ownership
- [02-01]: Synchronous persist() on every mutation — acceptable for <500 tasks; no async/debouncing needed
- [02-02]: NSWindow.didBecomeKeyNotification (not onAppear) for auto-focus — FloatingPanel reuses NSHostingView on show/hide cycles; onAppear only fires once on first show
- [02-02]: DispatchQueue.main.async in notification handler — window may not be fully promoted to key at notification fire time; async dispatch ensures safe focus assignment
- [02-03]: .toggleStyle(.checkbox) for native macOS HIG checkbox — not hand-rolled custom toggle
- [02-03]: .opacity(0.4) on outer HStack not just Text — entire row fades when complete (checkbox + text + delete icon)
- [02-03]: Completed tasks never filtered from list — TASK-03 requirement; only visual styling changes
- [02-03]: .listRowSeparator(.hidden) on TaskRowView rows — row provides own structure; default separators add noise
- [02-03]: Tasks display in insertion order — no sorting applied (research Open Question 3 resolved)
- [03-01]: Hidden Window scene (hidden-settings-bridge) declared FIRST in App body — SwiftUI resolves scenes in declaration order; Settings scene needs this context for @Environment(\.openSettings)
- [03-01]: NotificationCenter bridge (AppDelegate posts .openSettingsRequest; HiddenWindowView receives) — @Environment(\.openSettings) unavailable in AppKit code; notification is the only bridge
- [03-01]: sendAction(on: [.leftMouseDown, .rightMouseDown]) instead of statusItem.menu — setting .menu overrides button.action and breaks left-click panel toggle
- [03-01]: SMAppService.mainApp.status queried at runtime, never stored in Defaults — user can change launch-at-login in System Settings independently; stale Bool would desync UI
- [03-01]: #if DEBUG guard on SMAppService.register/unregister — SPM executables without proper .app bundle may fail; dev builds skip and log warning; release builds call API
- [03-01]: Defaults 9.0.0 added as SPM dependency — type-safe UserDefaults for future preference storage (launch-at-login not stored there)
- [03-02]: ContentUnavailableView (macOS 14+ native) over hand-rolled VStack/Text empty state — HIG-compliant, automatic accessibility, proper centering
- [03-02]: animationBehavior = .utilityWindow over manual NSAnimationContext alpha approach — simpler, native, sufficient for v1
- [03-02]: alphaValue = 1.0 reset before show() — guards against rapid toggle leaving panel invisible when animation is interrupted mid-fade

### Pending Todos

None yet.

### Blockers/Concerns

- [01-03 deferred]: Runtime verification of all Phase 1 and Phase 2 requirements must be done on macOS before Phase 3 begins. Dev environment is Linux (Fedora); Swift toolchain and macOS APIs unavailable.
- [Future]: App Store vs. direct distribution decision is deferred until after v1 ships — no technical impact on current work.
- [Resolved]: Default hotkey Cmd+Shift+Space selected — avoids Spotlight (Cmd+Space), screenshots (Cmd+Shift+3/4/5), Mission Control (Ctrl+Up).

## Session Continuity

Last session: 2026-02-18
Stopped at: Completed 03-02-PLAN.md (ContentUnavailableView empty state on TaskListView; animationBehavior = .utilityWindow + alphaValue safety reset on FloatingPanel/PanelManager).
Resume file: None
