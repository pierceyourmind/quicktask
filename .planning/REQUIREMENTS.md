# Requirements: QuickTask

**Defined:** 2026-02-17
**Core Value:** Zero-friction task capture — the moment a task enters your mind, one hotkey and a few keystrokes saves it before it vanishes.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### App Shell

- [ ] **SHELL-01**: Menu bar icon visible in macOS status bar at all times
- [ ] **SHELL-02**: App runs as menu bar agent (no Dock icon, LSUIElement)
- [ ] **SHELL-03**: Floating panel appears centered on screen (Spotlight-style) when activated
- [ ] **SHELL-04**: Panel dismisses on Escape key press
- [ ] **SHELL-05**: Panel dismisses on click outside the panel

### Hotkey

- [ ] **HKEY-01**: Global keyboard shortcut toggles floating panel open/closed
- [ ] **HKEY-02**: Hotkey works when app is in background (any app focused)
- [ ] **HKEY-03**: Panel appears in < 200ms perceived latency on hotkey press
- [ ] **HKEY-04**: Focus returns to previous app when panel is dismissed

### Task Capture

- [ ] **CAPT-01**: Text field is auto-focused when panel opens
- [ ] **CAPT-02**: User types task text and presses Return to add task
- [ ] **CAPT-03**: Text field clears after task is added, ready for next entry
- [ ] **CAPT-04**: Tasks appear in a checklist below the text field

### Task Management

- [ ] **TASK-01**: Each task has a checkbox to mark it complete
- [ ] **TASK-02**: Completed tasks show strikethrough and reduced opacity (faded)
- [ ] **TASK-03**: Completed tasks remain visible in the list (not auto-deleted)
- [ ] **TASK-04**: User can delete individual tasks

### Persistence

- [ ] **PERS-01**: Tasks persist across app quit and relaunch
- [ ] **PERS-02**: Tasks persist across system reboot
- [ ] **PERS-03**: Data stored locally as JSON in ~/Library/Application Support/

### Settings

- [ ] **SETT-01**: Launch at login toggle (opt-in, defaults to off)
- [ ] **SETT-02**: Settings accessible from menu bar icon context menu

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhancements

- **ENHC-01**: Task count badge on menu bar icon (active task count)
- **ENHC-02**: Drag-to-reorder tasks with drag handles
- **ENHC-03**: Configurable hotkey via recorder UI
- **ENHC-04**: Bulk-clear completed tasks ("Clear all done" button)
- **ENHC-05**: Optional due date field (single date, no recurrence)
- **ENHC-06**: Keyboard shortcut to mark selected task complete
- **ENHC-07**: Plain text export / copy task list to clipboard

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cloud sync / iCloud | Destroys local-only simplicity; adds entitlements, sign-in, conflict resolution |
| Multiple lists / projects | Kills single-place simplicity that makes menu bar app work |
| Tags / labels / priorities | Adds management UI and filter UI; complexity doubles for modest value |
| Subtasks / nested tasks | Checklist grows into project manager; use OmniFocus/Things instead |
| Reminders / notifications | Fundamentally changes app from scratchpad to scheduler |
| Markdown in tasks | Task titles are one-line; rich formatting irrelevant at that granularity |
| Mobile companion app | macOS only — deliberate constraint |
| Accounts / authentication | Personal local tool, no users |
| Menu bar text display of current task | Eats menu bar real estate; intrusive on laptops |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHELL-01 | Phase 1 | Pending |
| SHELL-02 | Phase 1 | Pending |
| SHELL-03 | Phase 1 | Pending |
| SHELL-04 | Phase 1 | Pending |
| SHELL-05 | Phase 1 | Pending |
| HKEY-01 | Phase 1 | Pending |
| HKEY-02 | Phase 1 | Pending |
| HKEY-03 | Phase 1 | Pending |
| HKEY-04 | Phase 1 | Pending |
| CAPT-01 | Phase 2 | Pending |
| CAPT-02 | Phase 2 | Pending |
| CAPT-03 | Phase 2 | Pending |
| CAPT-04 | Phase 2 | Pending |
| TASK-01 | Phase 2 | Pending |
| TASK-02 | Phase 2 | Pending |
| TASK-03 | Phase 2 | Pending |
| TASK-04 | Phase 2 | Pending |
| PERS-01 | Phase 2 | Pending |
| PERS-02 | Phase 2 | Pending |
| PERS-03 | Phase 2 | Pending |
| SETT-01 | Phase 3 | Pending |
| SETT-02 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

---
*Requirements defined: 2026-02-17*
*Last updated: 2026-02-17 after research completion*
