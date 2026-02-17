# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-17)

**Core value:** Zero-friction task capture — one hotkey and a few keystrokes saves a task before it vanishes
**Current focus:** Phase 1 — App Shell, Hotkey, and Floating Panel

## Current Position

Phase: 1 of 3 v1 phases (App Shell, Hotkey, and Floating Panel)
Plan: 2 of 3 in current phase
Status: In progress
Last activity: 2026-02-17 — Plan 01-02 complete (NSStatusItem + FloatingPanel + PanelManager)

Progress: [██░░░░░░░░] 22%

## Performance Metrics

**Velocity:**
- Total plans completed: 2
- Average duration: 2 min
- Total execution time: 4 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-app-shell-hotkey-floating-panel | 2 | 4 min | 2 min |

**Recent Trend:** 2 plans completed

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

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1 planning]: Default hotkey must be validated against system shortcut list before finalizing. Recommended: Cmd+Shift+Space or Ctrl+Option+Space. Avoid Cmd+Space (Spotlight), Cmd+Shift+3/4/5 (screenshots).
- [Future]: App Store vs. direct distribution decision is deferred until after v1 ships — no technical impact on current work.

## Session Continuity

Last session: 2026-02-17
Stopped at: Completed 01-02-PLAN.md (NSStatusItem menu bar icon, FloatingPanel NSPanel subclass, PanelManager toggle)
Resume file: None
