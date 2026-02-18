# Project Research Summary

**Project:** QuickTask — macOS menu bar task capture app
**Domain:** Native macOS menu bar utility (SwiftUI + AppKit hybrid)
**Researched:** 2026-02-18 (v1.1 update; original v1.0 summary superseded)
**Confidence:** HIGH

## Executive Summary

QuickTask is an existing v1 macOS menu bar checklist app now targeting its v1.1 milestone, adding four features to a live 843-LOC, 15-file codebase: task count badge on the menu bar icon, drag-to-reorder with drag handles, user-configurable hotkey via a recorder UI, and bulk-clear completed tasks. Research confirms all four features are implementable using the existing stack (Swift 6.1, SwiftUI + AppKit hybrid, `@Observable` state, `KeyboardShortcuts` library, JSON persistence) with no new third-party dependencies. The one required change is bumping the `KeyboardShortcuts` package constraint from `exact: "1.10.0"` to `from: "2.4.0"` to access the `Recorder` SwiftUI view. The v1 architecture is well-structured and v1.1 touches only 6 of 15 files plus 1 new file.

The recommended implementation order flows bottom-up through the component hierarchy: `TaskStore` mutations first (shared foundation for badge, drag-reorder, and bulk-clear), then `AppDelegate` badge wiring, then `TaskListView`/`TaskRowView` changes for drag-reorder, then the new `TaskToolbarView` for bulk-clear, and finally `SettingsView` additions for the configurable hotkey recorder. This ordering is deterministic from the dependency graph and eliminates forward-reference compilation errors. Steps 5 (`TaskToolbarView`) and 7 (`SettingsView`) are fully independent of each other and can be built in any order.

The most critical risks are well-understood and preventable with correct upfront decisions: (1) badge dark mode inversion if `isTemplate = true` is left on a composited badge image — use `button.title` instead of image compositing entirely; (2) SwiftUI `onMove` gesture interference with checkbox taps — the `moveDisabled(!isDragHandleHovered)` + `onHover` drag handle pattern is required from the first line, not as a retrofit; (3) `KeyboardShortcuts.Recorder` unresponsiveness if the floating panel races to retain key window status when Settings opens — fixed by one explicit `PanelManager.shared.hide()` call before `makeKeyAndOrderFront`. None of these risks require research beyond what has already been done; they require implementation discipline.

## Key Findings

### Recommended Stack

The existing stack requires no new dependencies for v1.1. Swift 6.1 with `@Observable` + `@MainActor` handles all state and threading concerns. `KeyboardShortcuts 2.4.0` (sindresorhus) adds the configurable hotkey recorder UI as a single SwiftUI `Form` row. Badge display uses `NSStatusItem` with `variableLength` and `button.title` — the simpler and more robust approach versus NSImage compositing. Drag-reorder uses SwiftUI `.onMove` on `ForEach` (not on `List` directly) with a `moveDisabled` + `onHover` pattern that prevents gesture interference with checkboxes. Bulk-clear uses SwiftUI `.confirmationDialog` (macOS 12+, safe on the macOS 14 minimum target).

**Core technologies:**
- Swift 6.1 (Xcode 16.3): primary language — strict concurrency; `@MainActor` required for all `NSStatusItem`/AppKit writes
- SwiftUI (macOS 14+): all panel UI including new `TaskToolbarView` and `SettingsView` additions
- AppKit (`NSStatusItem` + `NSPanel`): menu bar icon and floating panel — unchanged from v1; `NSStatusItem` switches from `squareLength` to `variableLength` for badge
- `KeyboardShortcuts 2.4.0` (sindresorhus SPM): configurable hotkey + recorder UI — version bump from pinned `1.10.0` is the only package change required
- `Defaults 9.0.6` (sindresorhus SPM): app preferences — already in project, no changes needed
- JSON + `FileManager` (`Codable`): task persistence — full-array write-through already handles all v1.1 mutations without schema changes

**What not to use:** `MenuBarExtra(.window)` (cannot be toggled from global hotkey), `NSStatusItem.squareLength` for badge (clips badge text), `isTemplate = true` on composited badge image (strips badge color in dark mode), `Combine` (replaced by `@Observable`), `NSTableView` for drag-reorder (drops out of SwiftUI unnecessarily), `.alert` for bulk-clear (`.confirmationDialog` is the HIG-correct pattern for multi-action destructive operations).

See `.planning/research/STACK.md` for full alternatives considered, version compatibility table, and project setup instructions.

### Expected Features

v1 shipped all table-stakes features. v1.1 adds the four P2 (competitive differentiator) features from the original feature matrix.

**Must have (table stakes — all shipped in v1):**
- Global hotkey to open panel
- Type + Return to capture tasks
- Checklist with checkboxes and visual completion state
- Completed tasks fade but persist (strikethrough + opacity)
- Escape / click-outside dismiss
- Delete tasks
- Launch at login (opt-in, `SMAppService`)
- Local file persistence

**Should have (v1.1 target — MEDIUM user value, LOW-MEDIUM implementation complexity):**
- Task count badge on menu bar icon — active tasks only; hide when count is 0; use `button.title` not image compositing
- Drag-to-reorder — requires `moveDisabled` + `onHover` drag handle pattern and `.onInsert` crash guard; `Array.move(fromOffsets:toOffset:)` is the canonical implementation
- Configurable hotkey — `KeyboardShortcuts.Recorder` in Settings; `Package.swift` version bump required; migrate from hardcoded value
- Bulk-clear completed — conditional footer button; `confirmationDialog` required; single `removeAll` + single `persist()` call

**Defer (v2+):**
- Optional due date (single date, no recurrence; only if user research shows demand)
- Spotlight-style panel aesthetic (custom `NSPanel` visual polish)
- Keyboard shortcut to mark task complete (Space bar on selected row)
- Plain text export / copy to clipboard

**Anti-features — never build:**
- Cloud sync / iCloud (destroys local-first, zero-account core value)
- Subtasks / nested tasks (feature creep into project management territory)
- Multiple lists / projects (kills single-list simplicity)
- Auto-clear completed tasks (removes user agency; bulk-clear is the intentional escape valve)
- Tags / labels / priorities (a different app entirely)

**Key dependency:** Drag-to-reorder requires `Array.move(fromOffsets:toOffset:)` in `TaskStore.move()` — not manual index arithmetic. The `destination` parameter from `onMove` uses a "target slot after removals" convention that does not map to a naive swap. Configurable hotkey is the only v1.1 feature that requires a `SettingsView` UI — plan it as a settings screen addition, not an afterthought.

See `.planning/research/FEATURES.md` for full feature dependency graph, competitor analysis table, and feature prioritization matrix.

### Architecture Approach

v1.1 touches 6 existing files and adds 1 new file (`TaskToolbarView.swift`). The 9 remaining files are unchanged. The `@Observable` / `withObservationTracking` pattern bridges the AppKit layer (`AppDelegate` badge) to the SwiftUI state layer without introducing Combine or additional coupling. `HotkeyService` requires zero changes — `KeyboardShortcuts.Recorder` handles persistence to UserDefaults automatically, and `HotkeyService.register()` hooks the `Name` identifier (not a specific key combo), so new shortcuts take effect on the next keypress without any restart or re-registration.

**Component changes for v1.1:**
1. `AppDelegate` (modified) — hold `TaskStore` ref; switch to `variableLength` `NSStatusItem`; add `updateBadge(count:)` driven by `withObservationTracking` loop
2. `TaskStore` (modified) — add `var incompleteCount: Int` computed property, `func clearCompleted()`, `func move(fromOffsets:toOffset:)`
3. `TaskListView` (modified) — `List(store.tasks) { }` becomes `List { ForEach(store.tasks) { }.onMove { } }` + `.onInsert` crash guard
4. `TaskRowView` (modified) — add `@State var isDragHandleHovered = false`, drag handle `Image`, `moveDisabled(!isDragHandleHovered)`, `.onHover`
5. `TaskToolbarView` (new file) — conditional "Clear N completed" footer button + `confirmationDialog`
6. `ContentView` (modified) — add `Divider` + `TaskToolbarView()` to existing `VStack`
7. `SettingsView` (modified) — add `KeyboardShortcuts.Recorder` section; increase frame height from 150pt to ~230pt

**Build order (enforced by dependency graph):**
1. `TaskStore` — all other changes depend on its new methods/properties
2. `AppDelegate` — depends on `TaskStore.incompleteCount`
3. `TaskRowView` — drag handle state (no new deps, but must exist before step 4)
4. `TaskListView` — depends on `TaskRowView` drag handle + `TaskStore.move()`
5. `TaskToolbarView` — depends on `TaskStore.clearCompleted()`
6. `ContentView` — depends on `TaskToolbarView` existing
7. `SettingsView` — fully independent; can be done at any point

**Key architectural patterns introduced in v1.1:**
- `withObservationTracking` for AppKit badge sync: fires once per observed change, re-registers recursively; correct for low-frequency menu bar badge updates
- Conditional toolbar row: `TaskToolbarView` renders nothing (zero height) when `completedCount == 0`; wrap the Divider above it in the same conditional to avoid an orphaned separator
- `moveDisabled` + `onHover` for targeted drag handles: standard macOS pattern for any `List` row containing `Toggle`, `Button`, or `TextField` alongside draggable content

See `.planning/research/ARCHITECTURE.md` for full data flow diagrams, anti-patterns, integration boundary tables, and the complete updated system overview diagram.

### Critical Pitfalls

10 pitfalls documented across all 4 features. The 5 that must be addressed from the first line of implementation (prevention cost: 0-30 minutes each; recovery cost after shipping: MEDIUM):

1. **Badge `isTemplate` dark mode inversion** — Compositing a colored red badge onto a template `NSImage` causes the badge to disappear or invert in dark mode; template rendering discards all color. Use `button.title = "\(count)"` on a `variableLength` `NSStatusItem` instead. Switch to `button.title = ""` when count is 0 to collapse width. Zero image compositing needed.

2. **`onMove` gesture delays checkbox taps** — SwiftUI's `.onMove()` attaches a unified drag recognizer that adds a delay before interactive controls (Toggle, Button) receive taps. Use `moveDisabled(!isDragHandleHovered)` + `.onHover` on a `line.3.horizontal` SF Symbol drag handle icon in `TaskRowView`. Do not ship naive `.onMove` and add handles as a polish step.

3. **Cross-list drop crash** — When `.onMove` is active, SwiftUI enables drop acceptance for the list. External drags (Finder files, text from other apps dropped on the floating panel) crash with `Fatal error: Attempting to insert row` if no `.onInsert` handler exists. Add `.onInsert(of: ["com.apple.SwiftUI.listReorder"]) { _, _ in }` as a no-op alongside every `.onMove`. One line.

4. **`KeyboardShortcuts.Recorder` unresponsive in Settings** — If the floating panel retains key window status when Settings opens (timing race between `resignKey()` and `makeKeyAndOrderFront`), the recorder control ignores all mouse and keyboard input. Fix: call `PanelManager.shared.hide()` explicitly in `openSettingsFromMenu()` before `window.makeKeyAndOrderFront(nil)`. One line, prevents the race.

5. **Hotkey fires during recorder capture** — Pressing the current panel toggle shortcut while the recorder is active triggers the panel *and* attempts to record the shortcut. Call `KeyboardShortcuts.disable(.togglePanel)` when recording begins and `KeyboardShortcuts.enable(.togglePanel)` when recording ends. Also observe `NSWindow.willCloseNotification` on the settings window to call `enable` as a safety net if Settings is closed mid-recording.

See `.planning/research/PITFALLS.md` for the full "looks done but isn't" 12-item verification checklist, recovery cost estimates, and the complete pitfall-to-phase mapping table.

## Implications for Roadmap

The dependency graph points to a strict 4-phase implementation order within v1.1. The phases map directly to the 4 features, ordered by: (a) shared foundation first, (b) highest interaction risk second, (c) independent features third and fourth.

### Phase 1: Task Count Badge

**Rationale:** Badge is the lowest complexity feature (LOW) and establishes the critical `AppDelegate` ↔ `TaskStore` observation bridge via `withObservationTracking`. Getting this bridge correct first validates the AppKit-to-Observable pattern before drag-reorder adds its own interaction complexity. Badge is also the most visible quality signal — a broken badge in dark mode looks like a shipped bug.
**Delivers:** Active task count visible in menu bar; hides when count is 0; works in both light and dark mode; updates immediately on any task mutation.
**Addresses:** Table stakes badge UX (at-a-glance task count); differentiator in competitor analysis (no competitors show active count accurately without clutter).
**Avoids:** Pitfall 1 (badge `isTemplate` dark mode inversion — use `button.title`); Pitfall 2 (`squareLength` clips badge text — switch to `variableLength`); Pitfall 3 (off-main-thread `NSStatusItem` write — enforce `@MainActor` on `updateBadge`).
**Key implementation decisions:** `button.title` approach (not image compositing); `variableLength` set once at init; `withObservationTracking` recursive loop in `AppDelegate`.

### Phase 2: Drag-to-Reorder

**Rationale:** Highest implementation risk of the four features due to SwiftUI gesture interaction complexity and the crash vector from external drops on the floating panel. Placing this second, after `TaskStore.move()` is established in Phase 1 groundwork, and before bulk-clear, gives maximum time for on-device interaction testing. Drag-reorder is also the feature users will notice most if the checkbox interaction feels sluggish.
**Delivers:** Manual task prioritization via hover-visible drag handle; list reorders in real time; order persists across restarts.
**Addresses:** Top differentiator vs. competitors (ToDoBar uses clunky arrow buttons; proper drag handle reorder is the macOS standard).
**Avoids:** Pitfall 4 (`onMove` delays checkbox taps — `moveDisabled` + `onHover` drag handle pattern required); Pitfall 5 (cross-list drop crash — `.onInsert` no-op guard required); Pitfall 6 (wrong index arithmetic — use `Array.move(fromOffsets:toOffset:)` not manual swap).
**Key implementation decisions:** `List { ForEach(...).onMove.onInsert }` structure; `@State var isDragHandleHovered` local to `TaskRowView`; completed tasks use `moveDisabled(task.isCompleted)` and accumulate below active tasks.

### Phase 3: Configurable Hotkey

**Rationale:** Fully independent of Phases 1 and 2 at the code level — touches only `SettingsView` and the `Package.swift` version constraint. Ordering it third gives the codebase a stable baseline before introducing the key window timing race condition that is unique to this feature. The `Package.swift` version bump should be the first commit of this phase.
**Delivers:** User-configurable panel toggle shortcut with system-native recorder UI in Settings; existing users who have never changed their shortcut see no behavior change (library defaults preserve the existing key combo).
**Addresses:** MEDIUM-value differentiator; Things 3 and Alfred have configurable hotkeys; QuickTask users whose shortcut conflicts with another app are currently stuck.
**Avoids:** Pitfall 7 (recorder unresponsive due to panel key window race — `PanelManager.hide()` before `makeKeyAndOrderFront`); Pitfall 8 (current hotkey fires during recorder capture — `KeyboardShortcuts.disable/enable` around recording state + `willCloseNotification` safety net).
**Key implementation decisions:** `Package.swift` bump to `from: "2.4.0"` first; `SettingsView` frame height increase to ~230pt; do not attempt to resize `KeyboardShortcuts.Recorder` via `.frame()` (confirmed non-functional in GitHub issue #133).

### Phase 4: Bulk-Clear Completed

**Rationale:** Lowest complexity (LOW) of the four features. `TaskStore.clearCompleted()` is a natural companion to the mutations established in Phase 1. `TaskToolbarView` is a new file with no compile-time dependencies on Phases 2-3 features, so it could technically be built earlier — but sequencing it last gives the `ContentView` layout a fully stable structure before the final VStack addition.
**Delivers:** One-tap cleanup of completed tasks with confirmation gate; conditional footer button visible only when completed tasks exist; rows animate out on clear.
**Addresses:** First-class escape valve for the "fade but persist" design contract established in v1 — users accumulate completed tasks, then clear them in batch on their own schedule.
**Avoids:** Pitfall 9 (bulk-clear with no row animation — try `withAnimation { store.clearCompleted() }` first; escalate to two-step removal if rows jump on real hardware); Pitfall 10 (destructive action without confirmation — `confirmationDialog` required from day one, never as a retrofit); performance trap of calling `persist()` N times (single `removeAll` + single `persist()`).
**Key implementation decisions:** `confirmationDialog` shows count ("Clear 5 completed?"); button disabled when `completedCount == 0`; `TaskToolbarView` Divider is inside the component (not in `ContentView`) to avoid orphaned separator when count is 0.

### Phase Ordering Rationale

- **`TaskStore` mutations are the shared foundation.** `incompleteCount` (badge), `move()` (drag-reorder), and `clearCompleted()` (bulk-clear) must all be added before their respective features can be implemented. This creates a natural "add store methods first" step that precedes each phase.
- **Badge first because the observation bridge is foundational.** The `withObservationTracking` loop in `AppDelegate` that drives badge updates is the same pattern that ensures the badge also updates after `clearCompleted()` in Phase 4. Establishing and testing it in Phase 1 means Phase 4 gets correct badge behavior for free.
- **Drag-reorder second because it has the highest interaction testing burden.** The `moveDisabled` + `onHover` pattern and the `.onInsert` crash guard both require on-device verification. More time between implementation and milestone release means more testing opportunity.
- **Configurable hotkey third** — fully independent, packages the `SettingsView` changes cleanly, and isolates the key window timing concern into its own phase.
- **Bulk-clear last** because it is the simplest feature and a clean finish — the milestone ends with a new component (`TaskToolbarView`) rather than a modification to an existing one.

### Research Flags

Phases with well-documented patterns — skip `/gsd:research-phase`:
- **Phase 1 (Badge):** `withObservationTracking` + `button.title` + `variableLength` pattern is fully specified in STACK.md and ARCHITECTURE.md with working code samples. No ambiguity.
- **Phase 3 (Configurable Hotkey):** `KeyboardShortcuts.Recorder` integration is documented in the library README; the key window race fix is fully specified in PITFALLS.md. Package version bump is a one-line change.
- **Phase 4 (Bulk-Clear):** `confirmationDialog` + `removeAll` + `persist()` is the complete implementation; ARCHITECTURE.md has the full `TaskToolbarView` code sample.

Phases that may warrant targeted research during planning:
- **Phase 2 (Drag-Reorder):** The `.onInsert` crash guard (Pitfall 5) and the `moveDisabled` + `onHover` pattern (Pitfall 4) have MEDIUM-confidence sources only (practitioner blogs, not official Apple docs). If implementation on the live codebase deviates from documented behavior — particularly if the `onMove` gesture still delays checkbox taps after adding the drag handle — targeted research into macOS-specific SwiftUI List drag behavior is warranted before declaring the feature complete.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Library versions verified on GitHub releases; all API patterns traced to official Apple docs; `KeyboardShortcuts` source examined directly for `Recorder` API |
| Features | HIGH | v1.1 target features verified against live competitor analysis (ToDoBar App Store reviews, Things 3 docs, macmenubar.com); expected behaviors grounded in macOS HIG |
| Architecture | HIGH | All integration surfaces verified against the live 843-LOC codebase; component boundaries confirmed; build order is deterministic from dependency graph; code samples confirmed compilable against target API surface |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls (Pitfalls 1-3, 7-8) have HIGH-confidence sources (official Apple docs, confirmed GitHub issues). Drag pitfalls (4-6) rely on MEDIUM-confidence practitioner blogs cross-referenced with Apple Developer Forums; all independently consistent |

**Overall confidence: HIGH**

### Gaps to Address

Three areas where research has documented the expected behavior but on-device validation is required during implementation:

- **Bulk-clear row animation:** PITFALLS.md documents that `withAnimation { store.clearCompleted() }` may or may not animate per-row removal on macOS depending on OS version — this is a known SwiftUI/macOS List animation limitation. The pragmatic approach (try `withAnimation` first, escalate to two-step removal if rows jump) is correct. Validate on real macOS hardware in Phase 4, not in Simulator.

- **`KeyboardShortcuts.Recorder` recording state observation:** PITFALLS.md notes that the SwiftUI `Recorder` view may not expose an `isRecording` binding as of the research date. If `Recorder` does not expose `onRecordingChange` in version 2.4.0, the `disable/enable` pattern for Pitfall 8 requires `RecorderCocoa` via `NSViewRepresentable` instead. Verify against the 2.4.0 source at the start of Phase 3 implementation.

- **`variableLength` menu bar layout transition:** Switching from `squareLength` to `variableLength` and setting `button.title = ""` / `"\(count)"` is documented to be seamless. Verify on a real menu bar with neighboring system status items (clock, Control Center, Spotlight) to confirm no visible layout jump when count transitions between 0 and 1. This is most visible with macOS notification badges active in other menu bar items.

## Sources

### Primary (HIGH confidence)
- Swift.org blog — Swift 6.1 released March 31, 2025: https://www.swift.org/blog/swift-6.1-released/
- GitHub: sindresorhus/KeyboardShortcuts releases — v2.4.0 confirmed Sep 18, 2025: https://github.com/sindresorhus/KeyboardShortcuts/releases
- GitHub: sindresorhus/KeyboardShortcuts source — `Recorder.swift` API verified: https://github.com/sindresorhus/KeyboardShortcuts/blob/main/Sources/KeyboardShortcuts/Recorder.swift
- GitHub: sindresorhus/KeyboardShortcuts issue #133 — `.frame()` sizing on Recorder non-functional: https://github.com/sindresorhus/KeyboardShortcuts/issues/133
- GitHub: sindresorhus/Defaults releases — v9.0.6 confirmed Oct 12, 2025: https://github.com/sindresorhus/Defaults/releases
- Apple Developer Documentation — NSStatusItem, NSStatusBarButton: https://developer.apple.com/documentation/appkit/nsstatusitem
- Apple Developer Documentation — NSImage.isTemplate (template image rendering): https://developer.apple.com/documentation/appkit/nsimage/istemplate
- Apple Developer Documentation — SwiftUI `.confirmationDialog` (macOS 12+): https://developer.apple.com/documentation/swiftui/view/confirmationdialog
- Apple Developer Documentation — `Array.move(fromOffsets:toOffset:)`: https://developer.apple.com/documentation/swift/array/move(fromoffsets:tooffset:)
- Apple Feedback FB11984872 — MenuBarExtra cannot programmatically toggle: https://github.com/feedback-assistant/reports/issues/383
- Apple Developer Forums — `onMove` macOS behavior, ForEach required: https://developer.apple.com/forums/thread/736419
- Live codebase analysis — 15 source files (843 LOC) read directly; all component boundaries verified at HIGH confidence

### Secondary (MEDIUM confidence)
- Cindori Developer Blog — floating panel pattern, MenuBarExtra limitation: https://cindori.com/developer/floating-panel
- NilCoalescing — drag-handle + `moveDisabled` pattern: https://nilcoalescing.com/blog/ListReorderingWhileStillBeingAbleToEditTheListItems/
- SwiftDevJournal — `.onMove` requires `ForEach` inside `List` on macOS: https://swiftdevjournal.com/moving-list-items-using-drag-and-drop-in-swiftui-mac-apps/
- SmallDeskSoftware — SwiftUI `onMove` crash without `.onInsert` guard: https://software.small-desk.com/en/swiftui-en/2021/03/28/swiftui-how-to-prevent-unexpected-crash-from-using-onmove-with-swiftui-list-foreach-investigation-memo/
- philz.blog — NSPanel key window timing with nonactivating style mask: https://philz.blog/nspanel-nonactivating-style-mask-flag/
- NilCoalescing — macOS menu bar utility in SwiftUI: https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/
- HackingWithSwift — `confirmationDialog` on macOS 12+: https://www.hackingwithswift.com/quick-start/swiftui/how-to-let-users-delete-rows-from-a-list
- ToDoBar App Store reviews — user complaints about missing hotkey and reorder UX: https://apps.apple.com/us/app/todobar-tasks-on-your-menu-bar/id6470928617
- Things 3 Quick Entry documentation — global hotkey pattern: https://culturedcode.com/things/support/articles/2249437/

### Tertiary (LOW confidence)
- WebSearch community consensus — macOS 14 as practical deployment floor for SwiftUI menu bar apps (Jan 2026 developer report)
- macmenubar.com — menu bar app ecosystem category overview

---
*Research completed: 2026-02-18*
*Ready for roadmap: yes*
