# Requirements: QuickTask

**Defined:** 2026-02-18
**Core Value:** Zero-friction task capture — one hotkey and a few keystrokes saves a task before it vanishes

## v1.1 Requirements

Requirements for v1.1 Polish & Reorder milestone. Each maps to roadmap phases.

### Badge

- [ ] **BADGE-01**: Menu bar icon shows active (incomplete) task count
- [ ] **BADGE-02**: Badge hidden when count is zero (icon-only)

### Reorder

- [ ] **REOR-01**: User can drag tasks to reorder via drag handle
- [ ] **REOR-02**: Task order persists across app restarts
- [ ] **REOR-03**: Drag handle visible on each task row (not full-row drag)

### Hotkey

- [ ] **HOTK-01**: User can change the global hotkey via recorder in Settings
- [ ] **HOTK-02**: New hotkey takes effect immediately after recording
- [ ] **HOTK-03**: User can reset hotkey to default (Cmd+Shift+Space)

### Clear

- [ ] **CLEAR-01**: User can bulk-clear all completed tasks
- [ ] **CLEAR-02**: Confirmation dialog shown before clearing
- [ ] **CLEAR-03**: "Clear" button only visible when completed tasks exist

## Future Requirements

Deferred beyond v1.1. Tracked but not in current roadmap.

### Organization

- **ORG-01**: Pin important tasks to top of list
- **ORG-02**: Search/filter tasks by keyword

### Polish

- **POL-01**: Keyboard navigation within task list (arrow keys)
- **POL-02**: Animated transitions for task add/remove/reorder

## Out of Scope

| Feature | Reason |
|---------|--------|
| Undo for bulk-clear | Adds undo stack complexity disproportionate to the risk |
| Auto-clear on check | Removes user agency — completed tasks should remain visible |
| Drag full row (no handle) | Gesture conflicts with checkboxes and future text fields |
| Multi-select for bulk operations | Over-engineering for a capture tool with ~10-50 tasks |
| Custom badge colors/styles | Resist feature creep — system-consistent appearance |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BADGE-01 | — | Pending |
| BADGE-02 | — | Pending |
| REOR-01 | — | Pending |
| REOR-02 | — | Pending |
| REOR-03 | — | Pending |
| HOTK-01 | — | Pending |
| HOTK-02 | — | Pending |
| HOTK-03 | — | Pending |
| CLEAR-01 | — | Pending |
| CLEAR-02 | — | Pending |
| CLEAR-03 | — | Pending |

**Coverage:**
- v1.1 requirements: 10 total
- Mapped to phases: 0
- Unmapped: 10 (pending roadmap)

---
*Requirements defined: 2026-02-18*
*Last updated: 2026-02-18 after initial definition*
