# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-17)

**Core value:** Zero-friction task capture — one hotkey and a few keystrokes saves a task before it vanishes
**Current focus:** Phase 2 — Task Data Model, Persistence, and Capture UI

## Current Position

Phase: 2 of 3 v1 phases (Task Data Model, Persistence, and Capture UI)
Plan: 2 of 3 in current phase
Status: Executing Phase 2
Last activity: 2026-02-17 — Completed 02-02: capture UI (TaskInputView with auto-focus, TaskListView, ContentView layout)

Progress: [████████░░] 56%

## Performance Metrics

**Velocity:**
- Total plans completed: 5
- Average duration: ~3 min
- Total execution time: ~17 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-app-shell-hotkey-floating-panel | 3 | ~14 min | ~4 min |
| 02-task-data-model-persistence-capture-ui | 2 | ~3 min | ~1.5 min |

**Recent Trend:** 5 plans completed

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
- [02-02]: TaskListView intentionally minimal (Text body only) — Plan 03 replaces with TaskRowView for checkbox/strikethrough/delete

### Pending Todos

None yet.

### Blockers/Concerns

- [01-03 deferred]: Runtime verification of all 9 Phase 1 requirements (SHELL-01 through SHELL-05, HKEY-01 through HKEY-04) must be done on macOS before Phase 2 begins. Dev environment is Linux (Fedora); Swift toolchain and macOS APIs unavailable.
- [Future]: App Store vs. direct distribution decision is deferred until after v1 ships — no technical impact on current work.
- [Resolved]: Default hotkey Cmd+Shift+Space selected — avoids Spotlight (Cmd+Space), screenshots (Cmd+Shift+3/4/5), Mission Control (Ctrl+Up).

## Session Continuity

Last session: 2026-02-17
Stopped at: Completed 02-02-PLAN.md (TaskInputView with auto-focus via NSWindow.didBecomeKeyNotification, TaskListView minimal list, ContentView real layout replacing placeholder).
Resume file: None
