# Roadmap: QuickTask

## Milestones

- ✅ **v1.0 MVP** — Phases 1-3 (shipped 2026-02-18)
- 🚧 **v1.1 Polish & Reorder** — Phases 4-7 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-3) — SHIPPED 2026-02-18</summary>

- [x] Phase 1: App Shell, Hotkey, and Floating Panel (3/3 plans) — completed 2026-02-17
- [x] Phase 2: Task Data Model, Persistence, and Capture UI (3/3 plans) — completed 2026-02-17
- [x] Phase 3: Settings, Launch at Login, and v1 Polish (2/2 plans) — completed 2026-02-18

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### 🚧 v1.1 Polish & Reorder (In Progress)

**Milestone Goal:** Add task count badge, drag-to-reorder, configurable hotkey, and bulk-clear completed to polish the v1.0 experience.

- [ ] **Phase 4: Task Count Badge** — Active task count visible in menu bar icon; hides at zero
- [ ] **Phase 5: Drag-to-Reorder** — Tasks reorderable via drag handle; order persists
- [ ] **Phase 6: Configurable Hotkey** — User can record a custom panel toggle shortcut in Settings
- [x] **Phase 7: Bulk-Clear Completed** — One-tap cleanup of completed tasks with confirmation (completed 2026-02-18)

## Phase Details

### Phase 4: Task Count Badge
**Goal**: The menu bar icon shows how many incomplete tasks the user has at a glance
**Depends on**: Phase 3 (v1.0 complete)
**Requirements**: BADGE-01, BADGE-02
**Success Criteria** (what must be TRUE):
  1. The menu bar icon displays the current count of incomplete tasks as a number next to the icon
  2. The badge number updates immediately whenever a task is added, completed, or deleted — no restart required
  3. When all tasks are completed or the list is empty, the badge disappears and the icon reverts to icon-only
  4. The badge reads correctly in both light mode and dark mode without color inversion
**Plans**: 1 plan
- [ ] 04-01-PLAN.md -- Badge display and reactive observation on NSStatusItem

### Phase 5: Drag-to-Reorder
**Goal**: Users can manually prioritize tasks by dragging them into any order, and that order survives restarts
**Depends on**: Phase 4
**Requirements**: REOR-01, REOR-02, REOR-03
**Success Criteria** (what must be TRUE):
  1. Each task row shows a drag handle icon (distinct from the checkbox) that the user can grab
  2. Hovering the drag handle and dragging reorders the task list in real time
  3. Tapping the checkbox on any task row works normally with no gesture delay or accidental reorder trigger
  4. Task order after a drag persists across app quit and relaunch
**Plans**: 1 plan
- [ ] 05-01-PLAN.md -- Drag handle, onMove reorder, and order persistence

### Phase 6: Configurable Hotkey
**Goal**: Users whose default Cmd+Shift+Space conflicts with another app can record a replacement shortcut in Settings
**Depends on**: Phase 4
**Requirements**: HOTK-01, HOTK-02, HOTK-03
**Success Criteria** (what must be TRUE):
  1. The Settings window contains a hotkey recorder control where the user can click and press a new key combination
  2. After recording, the new shortcut immediately toggles the panel — the old shortcut stops working with no restart
  3. The user can reset the hotkey to the default (Cmd+Shift+Space) from the same Settings UI
**Plans**: 1 plan
- [ ] 06-01-PLAN.md -- Dependency bump, hotkey recorder + reset button in Settings, window resize

### Phase 7: Bulk-Clear Completed
**Goal**: Users can remove all completed tasks in one action instead of deleting them one by one
**Depends on**: Phase 5
**Requirements**: CLEAR-01, CLEAR-02, CLEAR-03
**Success Criteria** (what must be TRUE):
  1. A "Clear N completed" button is visible in the task panel footer when one or more completed tasks exist
  2. Tapping the button shows a confirmation dialog before any tasks are removed
  3. Confirming the dialog removes all completed tasks at once and the list reflects the change immediately
  4. The "Clear" button is absent when no completed tasks exist — it does not appear as a disabled control
**Plans**: 1 plan
- [ ] 07-01-PLAN.md -- Add completedCount/clearCompleted to TaskStore and conditional footer button with confirmationDialog to TaskListView

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. App Shell, Hotkey, and Floating Panel | v1.0 | 3/3 | Complete | 2026-02-17 |
| 2. Task Data Model, Persistence, and Capture UI | v1.0 | 3/3 | Complete | 2026-02-17 |
| 3. Settings, Launch at Login, and v1 Polish | v1.0 | 2/2 | Complete | 2026-02-18 |
| 4. Task Count Badge | v1.1 | 0/1 | Planned | - |
| 5. Drag-to-Reorder | v1.1 | 0/? | Not started | - |
| 6. Configurable Hotkey | v1.1 | 0/? | Not started | - |
| 7. Bulk-Clear Completed | v1.1 | Complete    | 2026-02-18 | - |

---

*Roadmap created: 2026-02-17*
*Last updated: 2026-02-18 — v1.1 phases 4-7 added*
