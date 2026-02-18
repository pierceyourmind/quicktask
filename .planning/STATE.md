# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-18)

**Core value:** Zero-friction task capture — one hotkey and a few keystrokes saves a task before it vanishes
**Current focus:** v1.1 Phase 5 — Drag-to-Reorder

## Current Position

Phase: 5 of 7 (Drag-to-Reorder)
Plan: 1 of 1 in current phase
Status: Phase 5 complete
Last activity: 2026-02-18 — Phase 5 Plan 01 (drag-to-reorder) executed

Progress: [███░░░░░░░] 30% (v1.1 milestone — 2 of 4 phases complete)

## Performance Metrics

**Velocity (v1.0):**
- Total plans completed: 8
- Total execution time: ~2 days

**v1.1 — Phase 4 complete (1 plan, ~10 min, 2 files).**
**v1.1 — Phase 5 complete (1 plan, ~5 min, 3 files).**

## Accumulated Context

### Decisions

All v1.0 decisions logged in PROJECT.md Key Decisions table.

v1.1 decisions to make at implementation time:
- Phase 4: Use `button.title` (not image compositing) for badge; `variableLength` NSStatusItem
- Phase 5: `moveDisabled` + `onHover` drag handle pattern required from first line — not a retrofit
- Phase 6: Bump `KeyboardShortcuts` from pinned `1.10.0` to `from: "2.4.0"` as first commit of phase
- Phase 7: `confirmationDialog` (not `.alert`); single `removeAll` + single `persist()` call
- [Phase 04-task-count-badge]: variableLength NSStatusItem + button.title badge via withObservationTracking one-shot loop
- [Phase 05-drag-to-reorder]: onMove on ForEach (not List); per-row @State isHovering in TaskRowView; .foregroundStyle(.tertiary) for drag handle; no sortOrder field — array index IS persisted order

### Pending Todos

None.

### Blockers/Concerns

- [Open]: Runtime verification on macOS hardware still pending — dev environment is Linux (Fedora)
- [Open]: App Store vs. direct distribution decision deferred
- [Phase 5]: `onMove` + `onHover` drag handle interaction has MEDIUM-confidence sources only — validate on real hardware before declaring complete
- [Phase 6]: Verify `KeyboardShortcuts.Recorder` exposes `onRecordingChange` in v2.4.0; if not, use `RecorderCocoa` via NSViewRepresentable

## Quick Tasks

| # | Name | Status | Summary | Date |
|---|------|--------|---------|------|
| 1 | Share app as single file | Done | DMG packaging script via hdiutil | 2026-02-18 |

## Session Continuity

Last session: 2026-02-18
Stopped at: Completed 05-drag-to-reorder 05-01-PLAN.md
Resume file: .planning/phases/05-drag-to-reorder/05-01-SUMMARY.md
