---
phase: 06-configurable-hotkey
plan: 01
subsystem: ui
tags: [swift, swiftui, keyboard-shortcuts, hotkey, settings]

# Dependency graph
requires:
  - phase: 05-drag-to-reorder
    provides: TaskRowView with onMove + onHover drag handle pattern established
provides:
  - KeyboardShortcuts v2.4.0+ dependency in Package.swift
  - Hotkey recorder UI in Settings window bound to .togglePanel
  - Reset to Default button restoring Ctrl+Option+Space default
  - Settings window sized to 400x250 to accommodate both sections
affects:
  - 07-clear-all (Settings window established pattern)

# Tech tracking
tech-stack:
  added: ["KeyboardShortcuts v2.4.0+ (upgraded from pinned 1.10.0)"]
  patterns:
    - "KeyboardShortcuts.Recorder in SwiftUI Form Section for in-place hotkey recording"
    - "KeyboardShortcuts.reset() to restore default shortcut (NOT setShortcut(nil))"
    - "No onChange: callback needed — Carbon layer re-registers hotkey on UserDefaults change"

key-files:
  created: []
  modified:
    - QuickTask/Package.swift
    - QuickTask/Sources/Settings/SettingsView.swift
    - QuickTask/Sources/App/AppDelegate.swift

key-decisions:
  - "Bump KeyboardShortcuts from exact: 1.10.0 to from: 2.4.0 to access SwiftUI Recorder view"
  - "Use KeyboardShortcuts.reset(.togglePanel) not setShortcut(nil) — reset restores default, nil removes it entirely"
  - "No onChange: callback on Recorder — library's Carbon layer handles re-registration automatically"
  - "HotkeyService.swift untouched — onKeyUp(for: .togglePanel) remains active for any recorded shortcut"

patterns-established:
  - "KeyboardShortcuts.Recorder: drop-in SwiftUI control, no extra wiring needed beyond name binding"
  - "NSWindow contentRect height must match SwiftUI frame height for proper window sizing"

requirements-completed:
  - HOTK-01
  - HOTK-02
  - HOTK-03

# Metrics
duration: 2min
completed: 2026-02-18
---

# Phase 06 Plan 01: Configurable Hotkey Summary

**KeyboardShortcuts.Recorder in Settings Form with reset-to-default, bumping library from 1.10.0 to 2.4.0**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-18T21:22:45Z
- **Completed:** 2026-02-18T21:24:07Z
- **Tasks:** 2 completed
- **Files modified:** 3

## Accomplishments

- Bumped KeyboardShortcuts dependency from pinned `exact: "1.10.0"` to `from: "2.4.0"` to access the SwiftUI Recorder view added in v2.x
- Added "Keyboard Shortcut" section to SettingsView with `KeyboardShortcuts.Recorder("Toggle Panel:", name: .togglePanel)` wired to the existing `.togglePanel` shortcut name
- Added "Reset to Default" button calling `KeyboardShortcuts.reset(.togglePanel)` which restores Ctrl+Option+Space (the `default:` value in HotkeyService.swift)
- Grew SettingsView frame and AppDelegate NSWindow contentRect from 150 to 250 height so both settings sections display without clipping

## Task Commits

Each task was committed atomically:

1. **Task 1: Bump KeyboardShortcuts dependency to v2.4.0+** - `bddcf5a` (chore)
2. **Task 2: Add hotkey recorder and reset button to Settings, grow window** - `ab1fd82` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `QuickTask/Package.swift` - KeyboardShortcuts changed from `exact: "1.10.0"` to `from: "2.4.0"`
- `QuickTask/Sources/Settings/SettingsView.swift` - Added import, "Keyboard Shortcut" section, Recorder, Reset button, frame 400x250
- `QuickTask/Sources/App/AppDelegate.swift` - NSWindow contentRect height changed from 150 to 250

## Decisions Made

- Used `KeyboardShortcuts.reset(.togglePanel)` for the Reset button, NOT `setShortcut(nil)` — `nil` removes the shortcut entirely, `reset()` restores the `default:` value defined in HotkeyService.swift
- No `onChange:` callback on the Recorder — the KeyboardShortcuts library's Carbon layer automatically re-registers the global hotkey when UserDefaults changes, so no extra wiring is required
- HotkeyService.swift was intentionally left untouched — `onKeyUp(for: .togglePanel)` remains active for whatever shortcut is recorded

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. `swift package resolve` was attempted on Linux but produced no output (expected behavior — resolution completes on macOS at build time). The Package.swift change is correct and will resolve on macOS.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Configurable hotkey feature complete — users can record a custom global shortcut in Settings
- Settings window now has two sections (General + Keyboard Shortcut) at 400x250
- Ready for Phase 07: Clear All (confirmationDialog pattern, single removeAll + persist() call)
- Runtime verification on macOS hardware still pending (dev environment is Linux)

---
*Phase: 06-configurable-hotkey*
*Completed: 2026-02-18*

## Self-Check: PASSED

- FOUND: QuickTask/Package.swift
- FOUND: QuickTask/Sources/Settings/SettingsView.swift
- FOUND: QuickTask/Sources/App/AppDelegate.swift
- FOUND: .planning/phases/06-configurable-hotkey/06-01-SUMMARY.md
- FOUND: bddcf5a (Task 1 commit - chore: bump KeyboardShortcuts)
- FOUND: ab1fd82 (Task 2 commit - feat: add recorder + reset button)
