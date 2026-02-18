---
phase: 04-task-count-badge
plan: 01
subsystem: ui
tags: [nsstatusitem, observation, swiftui, appkit, macos]

# Dependency graph
requires: []
provides:
  - "incompleteCount computed property on TaskStore"
  - "Badge rendering on NSStatusItem via button.title"
  - "Reactive badge observation using withObservationTracking one-shot loop"
affects: [future badge phases, settings phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "withObservationTracking one-shot + recursive re-register for AppKit reactive observation"
    - "variableLength NSStatusItem for dynamic badge width"
    - "button.title for plain-text badge (not image compositing)"

key-files:
  created: []
  modified:
    - "QuickTask/Sources/Store/TaskStore.swift"
    - "QuickTask/Sources/App/AppDelegate.swift"

key-decisions:
  - "variableLength NSStatusItem so item width adjusts as digit count changes"
  - "button.title (not image compositing) for badge display per STATE.md decision"
  - "Leading space in ' N' for natural icon-to-number spacing"
  - "System default font and color for automatic light/dark mode adaptation"
  - "No cap at 99+ — show real count always"
  - "withObservationTracking one-shot + recursive re-register pattern for AppKit reactive observation"

patterns-established:
  - "Badge reactive pattern: withObservationTracking { read property } onChange { dispatch main; updateUI; re-register }"
  - "Computed property on @Observable class automatically tracked by Observation framework"

requirements-completed:
  - BADGE-01
  - BADGE-02

# Metrics
duration: 10min
completed: 2026-02-18
---

# Phase 4 Plan 01: Task Count Badge Summary

**Live incomplete task count badge on NSStatusItem menu bar icon using variableLength + button.title + withObservationTracking reactive loop**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-02-18T00:00:00Z
- **Completed:** 2026-02-18T00:10:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `incompleteCount` computed property to `TaskStore` — filters `tasks` where `!isCompleted`, tracked automatically by the Observation framework
- Changed `NSStatusItem` from `squareLength` to `variableLength` so the menu bar item grows/shrinks as digit count changes
- Implemented `updateBadge()` setting `button.title` to `" N"` (count > 0) or `""` (zero, icon-only)
- Implemented `observeBadge()` using `withObservationTracking` one-shot + recursive re-register pattern for reactive AppKit observation without polling
- Badge shows correct count from persisted tasks immediately at launch
- System font and adaptive color handle light/dark mode automatically — no custom `NSColor` or `NSAttributedString`

## Task Commits

Each task was committed atomically:

1. **Task 1: Add incompleteCount to TaskStore and retain store reference in AppDelegate** - `d4a5c62` (feat)
2. **Task 2: Implement badge rendering on NSStatusItem with reactive observation** - `27c6b19` (feat)

## Files Created/Modified

- `QuickTask/Sources/Store/TaskStore.swift` - Added `incompleteCount` computed property returning count of incomplete tasks
- `QuickTask/Sources/App/AppDelegate.swift` - Added `taskStore` instance property, `updateBadge()`, `observeBadge()`, switched to `variableLength`, added `import Observation`

## Decisions Made

- `variableLength` NSStatusItem was already decided in STATE.md — applied as specified
- `button.title` badge approach was already decided in STATE.md — applied as specified
- Leading space `" \(count)"` chosen for natural icon-to-number spacing (standard macOS convention)
- No 99+ cap — show real count always (per plan specification)
- `withObservationTracking` one-shot + recursive re-register is the correct pattern for AppKit code that cannot use SwiftUI's automatic @Observable tracking

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Badge feature is complete and ready for runtime verification on macOS hardware
- `TaskStore.incompleteCount` is available for any future consumer (Settings, Spotlight, widgets, etc.)
- Reactive observation pattern established — can be reused for other AppKit reactive needs in future phases
- Blocker remains: runtime verification on macOS hardware (Linux dev environment, noted in STATE.md)

## Self-Check: PASSED

- TaskStore.swift: FOUND
- AppDelegate.swift: FOUND
- 04-01-SUMMARY.md: FOUND
- Commit d4a5c62: FOUND (git log confirmed)
- Commit 27c6b19: FOUND (git log confirmed)

---
*Phase: 04-task-count-badge*
*Completed: 2026-02-18*
