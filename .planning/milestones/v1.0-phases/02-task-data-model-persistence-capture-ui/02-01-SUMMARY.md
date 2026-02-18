---
phase: 02-task-data-model-persistence-capture-ui
plan: "01"
subsystem: database
tags: [swift, observable, json, filemanager, persistence, taskstore]

# Dependency graph
requires:
  - phase: 01-app-shell-hotkey-floating-panel
    provides: FloatingPanel, PanelManager, AppDelegate, ContentView host

provides:
  - Task value type (Codable, Identifiable) with UUID id, String title, Bool isCompleted, Date createdAt
  - FileStore: JSON read/write to ~/Library/Application Support/QuickTask/tasks.json with .atomic writes
  - TaskRepository: CRUD abstraction over FileStore
  - TaskStore: @Observable single source of truth with add/toggle/delete mutations
  - TaskStore injected into NSPanel SwiftUI environment via PanelManager.configure(with:)

affects:
  - 02-02 (capture UI — reads/writes TaskStore via @Environment(TaskStore.self))
  - 02-03 (task list UI — reads TaskStore.tasks for display)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Observable macro (macOS 14+ Observation framework) — no Combine, no ObservableObject"
    - "FileStore + TaskRepository layered persistence — FileStore is I/O, TaskRepository is CRUD abstraction"
    - "Synchronous persist() on every mutation — acceptable for <500 tasks per research"
    - ".atomic write option for crash-safe JSON persistence"
    - "NSHostingView environment injection — TaskStore must be injected here, not from SwiftUI App body"

key-files:
  created:
    - QuickTask/Sources/Model/Task.swift
    - QuickTask/Sources/Persistence/FileStore.swift
    - QuickTask/Sources/Persistence/TaskRepository.swift
    - QuickTask/Sources/Store/TaskStore.swift
  modified:
    - QuickTask/Sources/Panel/PanelManager.swift
    - QuickTask/Sources/App/AppDelegate.swift

key-decisions:
  - "AnyView wrapper for FloatingPanel generic parameter — FloatingPanel<some View> is invalid as stored property type; AnyView erases type so panel property can be declared as FloatingPanel<AnyView>?"
  - "configure(with:) pattern not singleton TaskStore — TaskStore created in AppDelegate and passed to PanelManager to keep ownership explicit"
  - "Synchronous persist on every mutation — acceptable for <500 tasks; no async/debouncing needed"

patterns-established:
  - "Data flow: TaskStore -> TaskRepository -> FileStore -> tasks.json"
  - "Injection flow: AppDelegate creates TaskStore -> PanelManager.configure(with:) -> FloatingPanel(rootView: ContentView().environment(store))"
  - "All mutations persist synchronously; no Combine/async"

requirements-completed: [PERS-01, PERS-02, PERS-03]

# Metrics
duration: 2min
completed: 2026-02-17
---

# Phase 02 Plan 01: Task Data Layer Summary

**@Observable TaskStore backed by JSON FileStore in Application Support, injected into NSPanel environment via PanelManager.configure(with:)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-17T22:17:29Z
- **Completed:** 2026-02-17T22:19:38Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Created complete four-layer data stack: Task model -> FileStore -> TaskRepository -> TaskStore
- TaskStore is @Observable (macOS 14+ Observation framework) — no Combine, no ObservableObject
- FileStore creates Application Support subdirectory and writes JSON with .atomic option for crash safety
- TaskStore wired into NSPanel SwiftUI environment so all hosted views can use @Environment(TaskStore.self)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Task model, FileStore, TaskRepository, and TaskStore** - `ba461c6` (feat)
2. **Task 2: Wire TaskStore into PanelManager and AppDelegate** - `d8c860d` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `QuickTask/Sources/Model/Task.swift` - Codable+Identifiable struct with UUID id, String title, Bool isCompleted, Date createdAt
- `QuickTask/Sources/Persistence/FileStore.swift` - JSON read/write to Application Support with createDirectory and .atomic writes
- `QuickTask/Sources/Persistence/TaskRepository.swift` - Thin CRUD abstraction over FileStore (swappable backend)
- `QuickTask/Sources/Store/TaskStore.swift` - @Observable single source of truth; add/toggle/delete each call persist()
- `QuickTask/Sources/Panel/PanelManager.swift` - Added configure(with:) method; panel now created on configure rather than lazily; panel stored as FloatingPanel<AnyView>?
- `QuickTask/Sources/App/AppDelegate.swift` - Added PanelManager.shared.configure(with: TaskStore()) before HotkeyService.shared.register()

## Decisions Made

- **AnyView wrapper for panel type:** `FloatingPanel<some View>` is invalid as a stored property type in Swift. Used `FloatingPanel<AnyView>?` with `AnyView(ContentView().environment(store))` as rootView to achieve type erasure while preserving environment injection.
- **configure(with:) not singleton:** TaskStore is owned by AppDelegate and passed to PanelManager. This keeps ownership explicit and avoids the singleton anti-pattern.
- **Synchronous persist():** Every mutation (add/toggle/delete) calls persist() synchronously. Research confirmed JSON encode+write of 500 tasks is negligible. No debouncing or async needed.

## Deviations from Plan

None - plan executed exactly as written.

Note: The plan mentioned `private var panel: FloatingPanel<some View>?` which is not valid Swift for a stored property. Used `FloatingPanel<AnyView>?` which achieves the same result. This is a minor syntax correction, not a behavioral deviation.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Data layer complete and ready for Phase 2 plans 02 and 03
- Plan 02: Capture UI can use @Environment(TaskStore.self) to call taskStore.add(title:)
- Plan 03: Task list UI can use @Environment(TaskStore.self) to read taskStore.tasks and call taskStore.toggle/delete
- TaskStore loads persisted tasks on init — tasks will survive app quit/relaunch

## Self-Check: PASSED

All 6 source files exist at correct paths. Both task commits (ba461c6, d8c860d) verified in git log.

---
*Phase: 02-task-data-model-persistence-capture-ui*
*Completed: 2026-02-17*
