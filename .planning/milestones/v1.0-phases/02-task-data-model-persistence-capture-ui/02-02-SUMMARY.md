---
phase: 02-task-data-model-persistence-capture-ui
plan: "02"
subsystem: ui
tags: [swiftui, appkit, focusstate, nswindow, taskstore, observable]

# Dependency graph
requires:
  - phase: 02-01
    provides: TaskStore with add/toggle/delete, @Observable, environment injection into NSHostingView
provides:
  - TaskInputView with NSWindow.didBecomeKeyNotification auto-focus and Return-to-add
  - TaskListView minimal plain-style List rendering tasks from TaskStore
  - ContentView replaced with VStack layout (TaskInputView + Divider + TaskListView) at 400x300
affects:
  - 02-03-task-management-ui (adds TaskRowView with checkbox/strikethrough/delete replacing Text body in TaskListView)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSWindow.didBecomeKeyNotification for auto-focus on every panel open (NOT onAppear — onAppear only fires once on first show when FloatingPanel reuses NSHostingView)"
    - "DispatchQueue.main.async for safe focus assignment after window becomes key"
    - "@FocusState for programmatic text field focus in SwiftUI"
    - "Minimal TaskListView pattern — Text(task.title) placeholder for Plan 03 replacement"

key-files:
  created:
    - QuickTask/Sources/Views/TaskInputView.swift
    - QuickTask/Sources/Views/TaskListView.swift
  modified:
    - QuickTask/Sources/Views/ContentView.swift

key-decisions:
  - "NSWindow.didBecomeKeyNotification (not onAppear) for auto-focus — onAppear only fires once because FloatingPanel reuses NSHostingView on show/hide cycles"
  - "DispatchQueue.main.async in notification handler — window may not be fully promoted to key at notification fire time"
  - "TaskListView kept minimal (Text only) — Plan 03 replaces with TaskRowView for checkbox/strikethrough/delete"
  - ".textFieldStyle(.plain) on TextField — no border chrome, matches Spotlight aesthetic"

patterns-established:
  - "Auto-focus pattern: @FocusState + NSWindow.didBecomeKeyNotification + DispatchQueue.main.async"
  - "Submit pattern: onSubmit { store.add(title:); text = ''; DispatchQueue.main.async { focus } }"

requirements-completed: [CAPT-01, CAPT-02, CAPT-03, CAPT-04]

# Metrics
duration: 1min
completed: 2026-02-17
---

# Phase 2 Plan 02: Capture UI Summary

**SwiftUI task capture panel with TextField auto-focus via NSWindow.didBecomeKeyNotification, Return-to-add, and plain List display**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-17T22:21:59Z
- **Completed:** 2026-02-17T22:23:04Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- TaskInputView delivers the zero-friction capture UX: panel opens, text field is immediately focused (no click), user types, hits Return, task appears
- Auto-focus fires on EVERY panel open via NSWindow.didBecomeKeyNotification — not just first open — which is the critical behavior that makes the "one hotkey + a few keystrokes" promise work
- ContentView replaces placeholder with real VStack layout at 400x300 with frosted glass regularMaterial background
- TaskListView minimal implementation confirms CAPT-04: tasks appear in the list after capture, ready for Plan 03 enhancement

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TaskInputView with auto-focus and Return-to-add** - `935acc7` (feat)
2. **Task 2: Replace ContentView placeholder, create minimal TaskListView** - `209fade` (feat)

**Plan metadata:** (docs commit — created after self-check)

## Files Created/Modified

- `QuickTask/Sources/Views/TaskInputView.swift` - TextField with @FocusState, NSWindow.didBecomeKeyNotification auto-focus, onSubmit adding to TaskStore
- `QuickTask/Sources/Views/TaskListView.swift` - Minimal plain-style List showing task titles from TaskStore environment
- `QuickTask/Sources/Views/ContentView.swift` - Replaced placeholder with VStack (TaskInputView + Divider + TaskListView), 400x300 frame, regularMaterial background

## Decisions Made

- NSWindow.didBecomeKeyNotification instead of onAppear for auto-focus — FloatingPanel reuses its NSHostingView (orderOut/orderFront, not close/recreate), so onAppear only fires once. The notification fires every time the panel becomes key.
- DispatchQueue.main.async wrapping focus assignment — required because the window may not be fully promoted to key window at the exact notification fire time.
- TaskListView intentionally minimal (Text body only) — Plan 03 replaces the body with TaskRowView to add checkbox, strikethrough, and delete. No point adding complexity here.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Full capture flow is functional: hotkey opens panel, text field auto-focuses, user types task, Return adds it, task appears in list below
- Plan 03 (02-03) can now replace `Text(task.title)` in TaskListView with TaskRowView to add checkbox, strikethrough on complete, and delete button
- No blockers

---
*Phase: 02-task-data-model-persistence-capture-ui*
*Completed: 2026-02-17*

## Self-Check: PASSED

- TaskInputView.swift: FOUND
- TaskListView.swift: FOUND
- ContentView.swift: FOUND
- 02-02-SUMMARY.md: FOUND
- Commit 935acc7 (TaskInputView): FOUND
- Commit 209fade (ContentView+TaskListView): FOUND
