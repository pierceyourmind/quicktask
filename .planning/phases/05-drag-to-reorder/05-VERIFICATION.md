---
phase: 05-drag-to-reorder
verified: 2026-02-18T14:15:00Z
status: human_needed
score: 4/4 must-haves verified
re_verification: false
human_verification:
  - test: "Hover the drag handle on a task row and drag it to a new position"
    expected: "The row moves in real time; the list reflects the new order; no accidental reorder triggered by hovering non-handle areas"
    why_human: "onHover + moveDisabled runtime interaction during an active drag cannot be verified statically — the PLAN itself flagged MEDIUM confidence on whether isHovering stays true while a drag is in flight on macOS hardware (acknowledged in STATE.md as open blocker)"
  - test: "Quit and relaunch the app after reordering tasks"
    expected: "Task list loads in the exact order it was left in — drag order survives restart"
    why_human: "File I/O and JSON round-trip correctness under actual app lifecycle requires runtime verification; static analysis confirms the path is wired but cannot simulate disk write + re-read"
  - test: "Click a checkbox on any task row (do NOT hover the drag handle first)"
    expected: "Toggle fires immediately with no gesture delay; task completes without triggering a drag reorder"
    why_human: "Gesture conflict between moveDisabled(true) default state and Toggle tap is a runtime interaction; static code confirms no onTapGesture is added to HStack (the known macOS bug FB7367473 workaround is in place), but real interaction must be validated on hardware"
---

# Phase 5: Drag-to-Reorder Verification Report

**Phase Goal:** Users can manually prioritize tasks by dragging them into any order, and that order survives restarts
**Verified:** 2026-02-18T14:15:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Each task row shows a drag handle icon (three-bar grip) to the left of the checkbox | VERIFIED | `TaskRowView.swift` L25: `Image(systemName: "line.3.horizontal")` with `.foregroundStyle(.tertiary)` appears at L25, before `Toggle` at L31 in the HStack |
| 2 | Hovering the drag handle and dragging reorders the task list in real time | VERIFIED (code) / NEEDS HUMAN (runtime) | `TaskListView.swift` L22-24: `.onMove { indices, newOffset in store.move(fromOffsets: indices, toOffset: newOffset) }` on `ForEach`. `TaskRowView.swift` L27-29: `.onHover { hovering in isHovering = hovering }` sets state that gates moveDisabled. Runtime interaction requires hardware validation. |
| 3 | Tapping the checkbox works normally with no gesture delay or accidental reorder trigger | VERIFIED (code) / NEEDS HUMAN (runtime) | `TaskRowView.swift` L55: `.moveDisabled(!isHovering)` defaults to `moveDisabled(true)` — drag is disabled unless handle is hovered. No `.onTapGesture` on HStack (known macOS bug FB7367473 avoided). `Toggle` at L31 uses `Binding` with `store.toggle(task)`. Runtime gesture conflict requires hardware validation. |
| 4 | Task order after a drag persists across app quit and relaunch | VERIFIED (code) / NEEDS HUMAN (runtime) | `TaskStore.swift` L71-74: `move()` calls `tasks.move(fromOffsets:toOffset:)` then `persist()`. `FileStore.save()` uses `JSONEncoder().encode(tasks)` — array order is preserved in JSON. `FileStore.load()` restores via `JSONDecoder().decode([Task].self, from: data)`. Full chain wired. Runtime round-trip requires app lifecycle validation. |

**Score:** 4/4 truths verified in code. All 4 require human/hardware validation for runtime confidence.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `QuickTask/Sources/Store/TaskStore.swift` | `move(fromOffsets:toOffset:)` mutation method | VERIFIED | L71-74: method exists with correct signature `func move(fromOffsets source: IndexSet, toOffset destination: Int)`, calls `tasks.move(fromOffsets:toOffset:)` at L72, calls `persist()` at L73 as last line. Follows established add/toggle/delete mutation pattern. |
| `QuickTask/Sources/Views/TaskListView.swift` | `ForEach` with `.onMove` wired to `store.move` | VERIFIED | L17-25: `List { ForEach(store.tasks) { ... }.onMove { indices, newOffset in store.move(fromOffsets: indices, toOffset: newOffset) } }`. Correct placement — `.onMove` is on `ForEach` (L22), not on `List`. |
| `QuickTask/Sources/Views/TaskRowView.swift` | Drag handle icon with `onHover` gating `moveDisabled` | VERIFIED | L21: `@State private var isHovering = false` (per-row, not shared). L25-29: `Image(systemName: "line.3.horizontal")` with `.onHover`. L55: `.moveDisabled(!isHovering)` as last modifier on HStack. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `TaskListView.swift` | `TaskStore.swift` | `onMove` closure calling `store.move(fromOffsets:toOffset:)` | WIRED | `store.move` found at `TaskListView.swift` L23 inside the `.onMove` closure at L22-24. Pattern `store\.move` confirmed present. |
| `TaskRowView.swift` | `TaskListView.swift` (drag system) | `moveDisabled(!isHovering)` gates which rows are draggable | WIRED | `TaskRowView.swift` L55: `.moveDisabled(!isHovering)`. `isHovering` is set by `.onHover` at L27-29, driven by hovering over `Image(systemName: "line.3.horizontal")` at L25. Pattern `moveDisabled.*isHovering` confirmed present. Per-row state confirmed — `@State private var isHovering = false` at L21 is inside `TaskRowView`, not in `TaskListView`. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| REOR-01 | 05-01-PLAN.md | User can drag tasks to reorder via drag handle | SATISFIED | `ForEach.onMove` wired to `store.move`; drag handle `Image` with `.onHover` activates drag. Full chain: handle hover -> `isHovering=true` -> `moveDisabled(false)` -> SwiftUI drag -> `onMove` fires -> `store.move` reorders array. |
| REOR-02 | 05-01-PLAN.md | Task order persists across app restarts | SATISFIED | `store.move` calls `persist()` -> `TaskRepository.save()` -> `FileStore.save()` encodes full array as JSON (order preserved). `FileStore.load()` restores same array order on next launch. No `sortOrder` field needed — array index IS the persisted order. |
| REOR-03 | 05-01-PLAN.md | Drag handle visible on each task row (not full-row drag) | SATISFIED | `Image(systemName: "line.3.horizontal")` with `.foregroundStyle(.tertiary)` renders on every row (inside `TaskRowView`). Full-row drag is disabled by default (`moveDisabled(!isHovering)` defaults to `moveDisabled(true)`). Drag only activates when pointer is over the handle icon. |

**Orphaned requirements check:** REQUIREMENTS.md maps REOR-01, REOR-02, REOR-03 to Phase 5. All three appear in `05-01-PLAN.md` frontmatter `requirements:` field. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `TaskListView.swift` | 10 | Word "placeholder" in doc comment about `ContentUnavailableView` | Info | Benign — comment describes the native macOS empty-state component as an "encouraging placeholder," not a code stub. No implementation impact. |

No blocker or warning anti-patterns found. No TODO/FIXME/XXX/HACK comments. No empty implementations (`return null`, `return {}`, `return []`). No stub handlers.

### Human Verification Required

#### 1. Handle Hover Activates Drag (Runtime)

**Test:** Launch the app, add 3+ tasks. Hover the mouse over the three-bar grip icon on a task row (not the checkbox, not the text). While hovering the grip, click and drag the row to a different position.
**Expected:** The row lifts and follows the cursor. A drop indicator appears between rows. Releasing drops the row at the new position. The list immediately reflects the new order.
**Why human:** The `onHover` + `moveDisabled` interaction during an active drag cannot be verified statically. The PLAN acknowledged MEDIUM confidence on whether `isHovering` remains `true` for the duration of a drag (SwiftUI may or may not fire `onHover` updates mid-drag on macOS). This was flagged as an open blocker in STATE.md requiring hardware validation before declaring the feature complete.

#### 2. Order Persists Across Restart

**Test:** Drag tasks to a new order. Quit the app completely (Cmd+Q or quit from menu bar). Relaunch. Observe the task list order.
**Expected:** Tasks appear in exactly the order they were left in after the drag. No reversion to previous or insertion order.
**Why human:** File I/O correctness and JSON round-trip order preservation under actual app lifecycle (including `applicationWillTerminate` flush behavior) requires runtime confirmation. The persistence chain is fully wired in code but cannot be simulated statically.

#### 3. Checkbox Fires Without Gesture Conflict

**Test:** Without hovering the drag handle first, click a task checkbox directly. Also try tapping quickly on multiple rows in sequence.
**Expected:** Each toggle fires immediately with no perceptible delay. No drag motion is accidentally initiated. The row does not lift or shift position.
**Why human:** The `moveDisabled(true)` default prevents drag, and the absence of `.onTapGesture` on the HStack avoids the known macOS bug (FB7367473). However, gesture recognizer interaction in a live `List` with `onMove` active can only be validated under real macOS event processing.

### Gaps Summary

No code gaps. All four observable truths are fully implemented and wired in the codebase:

- `TaskStore.move(fromOffsets:toOffset:)` exists with correct signature and calls `persist()` last (L71-74)
- `TaskListView` uses `List { ForEach.onMove }` pattern with `.onMove` correctly on `ForEach` not `List` (L17-24)
- `TaskRowView` has per-row `@State private var isHovering`, drag handle before Toggle, and `.moveDisabled(!isHovering)` as last HStack modifier (L21, L25-29, L55)
- Persistence chain: `store.move` -> `persist()` -> `TaskRepository.save()` -> `FileStore.save()` with atomic JSON write; load path restores array order exactly

Three human verification items remain — all are runtime/hardware validation of wired code, not code gaps. The PLAN pre-identified this as an open blocker. These cannot be resolved by further code analysis.

---

_Verified: 2026-02-18T14:15:00Z_
_Verifier: Claude (gsd-verifier)_
