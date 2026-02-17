# Roadmap: QuickTask

## Overview

QuickTask ships in three focused phases. Phase 1 resolves all critical architectural risks upfront by building the app shell, global hotkey, and floating panel correctly from day one — decisions made here cannot be retrofitted later. Phase 2 adds the full task data model, persistence, and capture UI on top of that proven scaffold, delivering the complete core experience. Phase 3 finishes v1 with launch-at-login, settings, and polish. A fourth phase captures post-validation enhancements that are correctly deferred until real usage patterns are known.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: App Shell, Hotkey, and Floating Panel** - Running macOS app with menu bar icon, global hotkey, and dismissible floating panel (completed 2026-02-17)
- [ ] **Phase 2: Task Data Model, Persistence, and Capture UI** - Full task capture and checklist with persistence across restarts
- [ ] **Phase 3: Settings, Launch at Login, and v1 Polish** - Complete v1 ready for daily use
- [ ] **Phase 4 (v1.x): Post-Validation Enhancements** - Task count badge, drag-to-reorder, configurable hotkey, bulk-clear

## Phase Details

### Phase 1: App Shell, Hotkey, and Floating Panel

**Goal**: A running macOS app with a persistent menu bar icon, a floating panel that opens and closes on a global hotkey, and correct dismissal behavior — with all six critical architectural pitfalls resolved before any UI or data work begins.

**Depends on**: Nothing (first phase)

**Requirements**: SHELL-01, SHELL-02, SHELL-03, SHELL-04, SHELL-05, HKEY-01, HKEY-02, HKEY-03, HKEY-04

**Success Criteria** (what must be TRUE):
  1. Menu bar icon is visible at all times; clicking it opens and closes the panel
  2. Pressing the global hotkey (default: Cmd+Shift+Space) opens the panel from any app, even when QuickTask has no focus
  3. Panel appears within 200ms perceived latency, centered on screen, Spotlight-style
  4. Pressing Escape or clicking outside the panel closes it
  5. After dismissal, keyboard focus returns to the previously active app (not QuickTask)

**Key architectural constraints this phase must satisfy:**
- Use `NSStatusItem` + custom `NSPanel` subclass — NOT `MenuBarExtra(.window)` (cannot be programmatically toggled)
- Panel uses `.nonactivatingPanel` + `canBecomeKey = true` + `panel.makeKey()` so it receives keyboard input without stealing focus
- Override `resignKey()` on the panel to return focus to the previous app
- `NSStatusItem` must be strongly retained on `AppDelegate` — ARC will silently deallocate a local reference
- Use `KeyboardShortcuts` SPM 2.4.0 for the global hotkey — never `SwiftUI.keyboardShortcut()` (does not fire when app is backgrounded)
- `LSUIElement = YES` in Info.plist to suppress the Dock icon
- Validate default hotkey (Cmd+Shift+Space) does not conflict with system shortcuts before shipping

**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md — Xcode project setup, SPM dependencies (KeyboardShortcuts, Defaults), AppDelegate, LSUIElement
- [ ] 01-02-PLAN.md — NSStatusItem + NSPanel subclass (FloatingPanel), panel show/hide wiring, activation policy
- [ ] 01-03-PLAN.md — HotkeyService, global hotkey registration, focus-return on dismiss, click-outside dismissal

---

### Phase 2: Task Data Model, Persistence, and Capture UI

**Goal**: The full task capture experience — user presses hotkey, types a task, presses Return, sees it in a checklist, can mark it done or delete it, and finds all tasks intact after quitting and relaunching the app.

**Depends on**: Phase 1

**Requirements**: CAPT-01, CAPT-02, CAPT-03, CAPT-04, TASK-01, TASK-02, TASK-03, TASK-04, PERS-01, PERS-02, PERS-03

**Success Criteria** (what must be TRUE):
  1. When the panel opens, the text input field is focused automatically — no click required
  2. Typing a task and pressing Return adds it to the list and clears the field, ready for the next entry
  3. Each task in the list has a checkbox; checking it strikes through the text and fades the row
  4. Checked tasks remain visible in the list (they are not deleted)
  5. Each task has a delete control that removes it permanently
  6. Quitting and relaunching the app shows the same task list, with completion states preserved

**Key architectural constraints this phase must satisfy:**
- Build data layer bottom-up: `Task` model -> `FileStore` -> `TaskRepository` -> `TaskStore` -> SwiftUI views
- Store tasks as JSON at `~/Library/Application Support/QuickTask/tasks.json` — never UserDefaults for task storage
- Views call `TaskStore` only — never touch `FileStore` directly
- Write to disk synchronously on every mutation (acceptable for <500 tasks; background queue is a later optimization)
- Use `@Observable` (macOS 14+) — no Combine needed

**Plans**: 3 plans

Plans:
- [ ] 02-01-PLAN.md — Task model, FileStore, TaskRepository, TaskStore data layer + PanelManager/AppDelegate wiring for TaskStore injection
- [ ] 02-02-PLAN.md — ContentView layout, TaskInputView with auto-focus (NSWindow.didBecomeKeyNotification) and Return-to-add, minimal TaskListView
- [ ] 02-03-PLAN.md — TaskRowView (checkbox, strikethrough, opacity, delete), TaskListView updated to use TaskRowView

---

### Phase 3: Settings, Launch at Login, and v1 Polish

**Goal**: A complete v1 that feels finished — opt-in launch at login so the app survives reboots, a Settings window accessible from the menu bar, an encouraging empty state, and smooth animations that make every interaction feel deliberate.

**Depends on**: Phase 2

**Requirements**: SETT-01, SETT-02

**Success Criteria** (what must be TRUE):
  1. Right-clicking the menu bar icon shows a context menu with a "Settings..." item
  2. Opening Settings shows at minimum a "Launch at Login" toggle that persists across app restarts
  3. Enabling "Launch at Login" causes the app to appear in the menu bar after a system reboot, without user action
  4. An empty task list shows an encouraging placeholder (e.g., "All clear.") rather than blank space
  5. The panel opens and closes with a smooth animation (no jarring snap)

**Key architectural constraints this phase must satisfy:**
- Use `SMAppService` for launch-at-login — query its `.status` at runtime rather than storing locally
- The Settings window requires a hidden zero-size `Window` scene declared first in the `App` body (workaround for `SettingsLink` / `openSettings()` silently failing in menu bar context)
- Use `Defaults` SPM 9.0.6 for type-safe preference storage
- Menu bar icon must be a template image (`.template`) so macOS applies the correct tint for light/dark menu bar

**Plans**: TBD

Plans:
- [ ] 03-01: SMAppService launch-at-login, Defaults SPM preferences, Settings window (hidden Window scene workaround)
- [ ] 03-02: Empty state view, panel open/close animation, menu bar template icon, app icon

---

### Phase 4 (v1.x): Post-Validation Enhancements

**Goal**: Quality-of-life features that are correctly deferred until real usage patterns are known — none are blocking for v1, and two (drag-to-reorder, configurable hotkey) have known implementation friction that should not slow the initial ship.

**Depends on**: Phase 3

**Requirements**: ENHC-01, ENHC-02, ENHC-03, ENHC-04 (v2 requirements — tracked, not in v1 coverage)

**Success Criteria** (what must be TRUE):
  1. Menu bar icon displays a badge with the count of incomplete tasks
  2. User can drag tasks to reorder them using visible drag handles (no tap-to-focus conflict with text fields)
  3. User can change the global hotkey from a recorder UI in Settings
  4. A "Clear all done" button removes all completed tasks in one action

**Key architectural constraints this phase must satisfy:**
- Task count badge: Update `NSStatusItem` button image dynamically from `TaskStore`
- Drag-to-reorder: Use explicit drag handles with `moveDisabled()` on text-field rows to avoid the SwiftUI `onMove` + text-field focus conflict (documented in research)
- Configurable hotkey: `KeyboardShortcuts.Recorder` component from the SPM library — depends on Phase 3 Settings window
- Bulk-clear: Filter `tasks` to `isCompleted == false` in `TaskStore`, write to disk

**Plans**: TBD

---

## Requirement Coverage Validation

All 22 v1 requirements map to exactly one phase. No orphans.

| Requirement | Description | Phase |
|-------------|-------------|-------|
| SHELL-01 | Menu bar icon visible at all times | Phase 1 |
| SHELL-02 | App runs as menu bar agent (no Dock icon) | Phase 1 |
| SHELL-03 | Floating panel centered on screen (Spotlight-style) | Phase 1 |
| SHELL-04 | Panel dismisses on Escape key | Phase 1 |
| SHELL-05 | Panel dismisses on click outside | Phase 1 |
| HKEY-01 | Global hotkey toggles panel open/closed | Phase 1 |
| HKEY-02 | Hotkey works when any other app is focused | Phase 1 |
| HKEY-03 | Panel appears in <200ms on hotkey press | Phase 1 |
| HKEY-04 | Focus returns to previous app on dismiss | Phase 1 |
| CAPT-01 | Text field auto-focused when panel opens | Phase 2 |
| CAPT-02 | Type task + Return to add it | Phase 2 |
| CAPT-03 | Text field clears after task is added | Phase 2 |
| CAPT-04 | Tasks appear in checklist below input | Phase 2 |
| TASK-01 | Each task has a checkbox to mark complete | Phase 2 |
| TASK-02 | Completed tasks show strikethrough + reduced opacity | Phase 2 |
| TASK-03 | Completed tasks remain visible (not auto-deleted) | Phase 2 |
| TASK-04 | User can delete individual tasks | Phase 2 |
| PERS-01 | Tasks persist across app quit and relaunch | Phase 2 |
| PERS-02 | Tasks persist across system reboot | Phase 2 |
| PERS-03 | Data stored as JSON in ~/Library/Application Support/ | Phase 2 |
| SETT-01 | Launch at login toggle (opt-in, default off) | Phase 3 |
| SETT-02 | Settings accessible from menu bar icon context menu | Phase 3 |

**Coverage: 22/22 v1 requirements mapped. 0 orphaned.**

---

## Phase Dependency Rationale

**Phase 1 must come first — all critical pitfalls live here.**
Every one of the six architectural pitfalls identified in research (NSPanel subclass, activation policy, NSStatusItem retention, hotkey API, focus-return behavior, SettingsLink workaround) is a Phase 1 concern, or requires a Phase 1 decision that cannot be retrofitted later. Discovering any of these in Phase 2 or 3 means rearchitecting the foundation. Front-loading them is the only low-risk ordering.

**Phase 2 builds on the proven panel scaffold.**
Once the panel opens and closes correctly, the data layer and UI have a stable host. Building data bottom-up (model -> FileStore -> TaskRepository -> TaskStore -> views) enforces the architecture's strict dependency direction and keeps views thin from day one. None of Phase 2's work is blocked by Phase 3.

**Phase 3 is last among v1 phases because it has no blockers in Phases 1-2.**
Launch-at-login (SMAppService) and Settings have no dependency on the data layer. Deferring them to Phase 3 keeps the critical path short: get the core capture experience working first, then add the settings surface.

**Phase 4 is correctly post-v1.**
Drag-to-reorder has a known SwiftUI text-field conflict that adds non-trivial implementation friction. Configurable hotkey depends on the Phase 3 Settings window. Task count badge and bulk-clear are features users request after accumulating a real task list — prioritizing them before shipping would be premature.

---

## Progress

**Execution Order:** 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. App Shell, Hotkey, and Floating Panel | 0/3 | Complete    | 2026-02-17 |
| 2. Task Data Model, Persistence, and Capture UI | 0/3 | Not started | - |
| 3. Settings, Launch at Login, and v1 Polish | 0/2 | Not started | - |
| 4. Post-Validation Enhancements (v1.x) | 0/TBD | Not started | - |

---

*Roadmap created: 2026-02-17*
*Last updated: 2026-02-17 after Phase 2 planning*
