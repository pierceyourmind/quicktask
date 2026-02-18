---
phase: 05-drag-to-reorder
plan: 01
subsystem: ui
tags: [swiftui, drag-reorder, list, foreach, onmove, macos]

# Dependency graph
requires:
  - phase: 04-task-count-badge
    provides: TaskStore @Observable pattern and TaskRowView/TaskListView established UI structure
provides:
  - move(fromOffsets:toOffset:) mutation on TaskStore with persistence
  - ForEach + onMove drag reorder in TaskListView
  - Drag handle icon with onHover-gated moveDisabled per row in TaskRowView
affects: [06-keyboard-shortcut-customization, 07-clear-all-completed]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "onMove placed on ForEach (DynamicViewContent conformance), never on List"
    - "moveDisabled(!isHovering) gates drag to handle hover only — prevents accidental reorders"
    - "@State private var isHovering = false scoped per-row for independent hover state"
    - "Array.move(fromOffsets:toOffset:) stdlib method matches onMove closure signature exactly"

key-files:
  created: []
  modified:
    - QuickTask/Sources/Store/TaskStore.swift
    - QuickTask/Sources/Views/TaskListView.swift
    - QuickTask/Sources/Views/TaskRowView.swift

key-decisions:
  - "moveDisabled + onHover drag handle pattern required from first implementation — not a retrofit"
  - "isHovering state in TaskRowView (per-row) not TaskListView (shared) — each row has independent drag gate"
  - "SF Symbol line.3.horizontal for drag handle with .foregroundStyle(.tertiary) — visually subordinate but present"
  - "onMove on ForEach not List — only DynamicViewContent has onMove; placing on List silently does nothing"
  - "No sortOrder field on Task struct — array index order IS the persisted order via existing JSON serialization"

patterns-established:
  - "Mutation pattern: all TaskStore mutations (add/toggle/delete/move) call persist() as last line"
  - "Drag gate: moveDisabled(!isHovering) + Image.onHover pattern for handle-only drag activation"

requirements-completed:
  - REOR-01
  - REOR-02
  - REOR-03

# Metrics
duration: 5min
completed: 2026-02-18
---

# Phase 5 Plan 01: Drag-to-Reorder Summary

**Drag handle (line.3.horizontal, .tertiary) on each row gates onMove via isHovering/moveDisabled; reorder persists via Array.move + TaskStore.persist()**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-02-18T13:48:55Z
- **Completed:** 2026-02-18T13:53:55Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- TaskStore.move(fromOffsets:toOffset:) mutation added — uses Swift stdlib Array.move and calls persist() for durable order (REOR-01, REOR-02)
- TaskListView updated from List(store.tasks) to List { ForEach.onMove } — the only placement where onMove has effect
- TaskRowView gains a visible three-bar grip handle (line.3.horizontal) with per-row isHovering state gating moveDisabled, so checkbox and delete button remain unaffected (REOR-03)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add move(fromOffsets:toOffset:) mutation to TaskStore** - `505f66e` (feat)
2. **Task 2: Wire drag handle, onMove, and moveDisabled in TaskListView and TaskRowView** - `cf8d1f5` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `QuickTask/Sources/Store/TaskStore.swift` - Added move(fromOffsets:toOffset:) mutation method after delete()
- `QuickTask/Sources/Views/TaskListView.swift` - Replaced List(store.tasks) with List { ForEach.onMove } pattern
- `QuickTask/Sources/Views/TaskRowView.swift` - Added @State isHovering, drag handle Image before Toggle, .moveDisabled(!isHovering) on HStack

## Decisions Made

- `moveDisabled` + `onHover` pattern required from first implementation — not a retrofit (per STATE.md pre-decision)
- Per-row `@State private var isHovering = false` in TaskRowView (not shared parent state) — prevents one row's handle hover from enabling drag on all rows
- `Image(systemName: "line.3.horizontal")` with `.foregroundStyle(.tertiary)` — handle is visible but visually subordinate to checkbox and task text
- `.onMove` must be on `ForEach` not `List` — `onMove` is defined on `DynamicViewContent`, which `ForEach` conforms to; placing on `List` silently does nothing
- No `sortOrder` field added to Task struct — array index in the serialized JSON array IS the persisted order; existing TaskRepository handles this correctly with no schema changes

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. All APIs are SwiftUI stdlib (macOS 14+), no new dependencies required.

**Hardware validation note:** MEDIUM confidence on `onHover` + `moveDisabled` runtime interaction during active drag — validate on real macOS hardware before declaring feature complete (existing blocker from STATE.md).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Drag-to-reorder UI is fully wired: store mutation, list binding, row handle all in place
- Runtime behavior on macOS hardware still pending validation (open blocker)
- Phase 6 (Keyboard Shortcut Customization) can proceed — no dependency on this phase
- Phase 7 (Clear All Completed) can proceed — TaskStore mutation pattern is established

---
*Phase: 05-drag-to-reorder*
*Completed: 2026-02-18*

## Self-Check: PASSED

- FOUND: QuickTask/Sources/Store/TaskStore.swift
- FOUND: QuickTask/Sources/Views/TaskListView.swift
- FOUND: QuickTask/Sources/Views/TaskRowView.swift
- FOUND: .planning/phases/05-drag-to-reorder/05-01-SUMMARY.md
- FOUND commit: 505f66e (Task 1)
- FOUND commit: cf8d1f5 (Task 2)
