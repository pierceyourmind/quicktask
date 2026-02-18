---
phase: 03-settings-launch-at-login-v1-polish
plan: "01"
subsystem: ui
tags: [smappservice, nsstatusitem, swiftui-settings, notification-bridge, template-image, defaults]

# Dependency graph
requires:
  - phase: 02-task-data-model-persistence-capture-ui
    provides: AppDelegate with NSStatusItem, QuickTaskApp SwiftUI App body, PanelManager
provides:
  - Settings window accessible via right-click context menu (SETT-02)
  - Launch at Login toggle backed by SMAppService (SETT-01)
  - Right-click context menu on menu bar icon with Settings... and Quit QuickTask
  - Left-click continues to toggle floating panel (existing behavior preserved)
  - Template image on menu bar icon for light/dark adaptation
  - Hidden SwiftUI Window scene bridging AppKit to @Environment(\.openSettings)
  - Defaults SPM dependency added (ready for future preferences)
  - Panel animation via animationBehavior = .utilityWindow + alphaValue safety reset
affects: [future-preferences, app-store-distribution, v1-release]

# Tech tracking
tech-stack:
  added:
    - "Defaults 9.0.0+ (sindresorhus/Defaults) — type-safe UserDefaults for future preferences"
    - "ServiceManagement framework — SMAppService.mainApp for launch-at-login"
  patterns:
    - "NotificationCenter bridge: AppDelegate posts .openSettingsRequest; HiddenWindowView receives and calls @Environment(\.openSettings)"
    - "Hidden 1x1 Window scene declared FIRST in App body to provide SwiftUI environment context for Settings scene"
    - "NSStatusItem dual-click: sendAction(on: [.leftMouseDown, .rightMouseDown]) + NSApp.currentEvent.isRightClick"
    - "Never set statusItem.menu (overrides button.action); show menu manually via popUp(positioning:at:in:)"
    - "SMAppService.mainApp.status as single source of truth for launch-at-login; never store in Defaults"
    - "DEBUG guard wraps SMAppService.register/unregister — fails gracefully in dev builds without bundle"
    - "activationPolicy juggling: .regular before openSettings(); .accessory restored after 200ms"

key-files:
  created:
    - "QuickTask/Sources/Settings/SettingsView.swift"
  modified:
    - "QuickTask/Sources/App/QuickTaskApp.swift"
    - "QuickTask/Sources/App/AppDelegate.swift"
    - "QuickTask/Package.swift"
    - "QuickTask/Sources/Panel/FloatingPanel.swift"
    - "QuickTask/Sources/Panel/PanelManager.swift"

key-decisions:
  - "Hidden Window scene (id: hidden-settings-bridge) declared FIRST in App body — SwiftUI resolves scenes in declaration order; Settings scene needs this context"
  - "NotificationCenter bridge (not direct call) — @Environment(\\/.openSettings) is unavailable in AppKit code; notification is the only path"
  - "sendAction(on: [.leftMouseDown, .rightMouseDown]) instead of statusItem.menu — setting .menu would override button.action and break left-click panel toggle"
  - "SMAppService.mainApp.status queried at runtime, never stored in Defaults — user can change it in System Settings independently"
  - "#if DEBUG guard on SMAppService.register/unregister — SPM executables without proper .app bundle may fail; dev builds skip registration and log a warning"
  - "Defaults 9.0.0 added as SPM dependency for future type-safe preference storage (no launch-at-login state stored there)"
  - "animationBehavior = .utilityWindow on FloatingPanel + alphaValue = 1.0 safety reset in show() — prevents stuck-invisible panel on rapid toggle"

patterns-established:
  - "Hidden Window bridge: use Window(id:) first in App body + onReceive(.openSettingsRequest) + openSettings() for opening Settings from AppKit"
  - "Dual-click NSStatusItem: sendAction(on: [.leftMouseDown, .rightMouseDown]) + NSApp.currentEvent?.isRightClick check"
  - "SMAppService pattern: read .status on onAppear; write register/unregister on toggle; never store Bool locally"

requirements-completed: [SETT-01, SETT-02]

# Metrics
duration: 3min
completed: 2026-02-18
---

# Phase 3 Plan 01: Settings Window and Launch at Login Summary

**SMAppService launch-at-login toggle in SwiftUI Settings window, opened via right-click NSStatusItem context menu using NotificationCenter bridge and hidden Window scene workaround**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-02-18T00:50:58Z
- **Completed:** 2026-02-18T00:53:24Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Settings window with SMAppService-backed Launch at Login toggle (SETT-01); reads .status at runtime, never from Defaults; DEBUG guard prevents register/unregister in dev builds
- Right-click context menu on menu bar icon with "Settings..." and "Quit QuickTask"; left-click still toggles floating panel (SETT-02)
- Hidden SwiftUI Window scene (hidden-settings-bridge, declared first) bridges AppKit to @Environment(\.openSettings) via NotificationCenter
- Template image (isTemplate = true) on menu bar icon for correct light/dark tinting
- Defaults 9.0.0 SPM dependency added for future type-safe preferences
- Panel animation polish: animationBehavior = .utilityWindow + alphaValue safety reset

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Defaults dependency, create SettingsView, restructure App body** - `7527a6e` (feat)
2. **Task 2: Add right-click context menu to NSStatusItem, template image** - `cf68fe4` (feat)

## Files Created/Modified

- `QuickTask/Sources/Settings/SettingsView.swift` - SwiftUI Form with Launch at Login toggle backed by SMAppService; requiresApproval hint; DEBUG guard
- `QuickTask/Sources/App/QuickTaskApp.swift` - Notification.Name.openSettingsRequest extension; HiddenWindowView with @Environment(\.openSettings); Window(hidden-settings-bridge) FIRST then Settings { SettingsView() }
- `QuickTask/Sources/App/AppDelegate.swift` - handleStatusItemClick replaces togglePanel; sendAction(on:); showContextMenu(); openSettingsFromMenu() posts notification; isTemplate = true; hides helper window on launch
- `QuickTask/Package.swift` - Added Defaults 9.0.0 to package-level and target-level dependencies
- `QuickTask/Sources/Panel/FloatingPanel.swift` - animationBehavior = .utilityWindow (pre-staged from prior session, included)
- `QuickTask/Sources/Panel/PanelManager.swift` - panel.alphaValue = 1.0 safety reset in show() (pre-staged from prior session, included)

## Decisions Made

- **Hidden Window scene declared first:** SwiftUI resolves scenes in declaration order; @Environment(\.openSettings) needs the hidden window's render context established before Settings {} is processed
- **NotificationCenter bridge required:** @Environment(\.openSettings) cannot be called from AppKit code (AppDelegate); NotificationCenter is the only bridge from NSStatusItem handler to SwiftUI environment action
- **sendAction(on:) not statusItem.menu:** Setting .menu on NSStatusItem overrides button.action entirely — left-click would show menu instead of toggling panel; the sendAction + currentEvent approach preserves both behaviors
- **SMAppService.mainApp.status as source of truth:** User can modify launch-at-login in System Settings independently; querying .status on onAppear prevents stale UI
- **#if DEBUG guard on register/unregister:** SPM executables (swift build) may lack proper bundle identity for SMAppService; failing silently in dev prevents false negative UX; release builds call the API

## Deviations from Plan

None - plan executed exactly as written.

Note: FloatingPanel.swift and PanelManager.swift had pre-staged changes (animationBehavior + alphaValue reset) from a prior session that were included in the Task 1 commit. These are valid Phase 3 panel polish changes consistent with the research (Pattern 6).

## Issues Encountered

None - all patterns well-documented in research; implementation proceeded without complications.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SETT-01 and SETT-02 complete — all v1 functional requirements delivered
- Settings window opens from right-click menu; Launch at Login toggle wired to SMAppService
- Runtime verification of all Phase 1-3 requirements still needed on macOS (dev environment is Linux)
- Next plan in Phase 3 (03-02) may cover remaining polish: empty state UI, ContentUnavailableView
- Launch-at-login requires a properly bundled .app for SMAppService to work (known limitation documented with DEBUG guard)

## Self-Check: PASSED

- FOUND: QuickTask/Sources/Settings/SettingsView.swift
- FOUND: QuickTask/Sources/App/QuickTaskApp.swift
- FOUND: QuickTask/Sources/App/AppDelegate.swift
- FOUND: QuickTask/Package.swift
- FOUND: Task 1 commit 7527a6e
- FOUND: Task 2 commit cf68fe4

---
*Phase: 03-settings-launch-at-login-v1-polish*
*Completed: 2026-02-18*
