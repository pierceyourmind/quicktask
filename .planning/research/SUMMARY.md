# Project Research Summary

**Project:** QuickTask — macOS Menu Bar Task Capture App
**Domain:** macOS menu bar utility (global hotkey + floating panel + local persistence)
**Researched:** 2026-02-17
**Confidence:** MEDIUM-HIGH

## Executive Summary

QuickTask is a lightweight macOS menu bar app providing zero-friction task capture via a global keyboard shortcut. The category is well-understood — apps like Things 3, ToDoBar, and Raycast establish clear patterns — and the recommended implementation is a tight stack of Swift 6.1, SwiftUI (for panel content), AppKit NSPanel (for the floating window), KeyboardShortcuts (sindresorhus), and JSON + FileManager persistence. There is no database, no cloud, no web layer. The entire app is roughly 8-10 Swift files and two SPM dependencies. This is a small project with well-documented patterns, and the research confirms that the scoped design brief is exactly right for the category.

The critical architectural decision is to use `NSStatusItem` + a custom `NSPanel` subclass rather than SwiftUI's `MenuBarExtra` with `.window` style. This is non-negotiable: `MenuBarExtra` cannot be programmatically toggled from a global hotkey registered outside the SwiftUI scene (confirmed Apple feedback FB11984872). Every element of the hotkey-first interaction model depends on the `NSPanel` approach being in place from day one. The panel must use `.nonactivatingPanel` so it receives keyboard input without stealing focus from the user's previous app — this is what makes QuickTask feel like Spotlight rather than a disruptive popup.

The primary risks are all front-loaded in Phase 1 and are well-understood with known mitigations. Using SwiftUI's `.keyboardShortcut()` for the global hotkey, skipping the `NSPanel` subclass, and failing to retain the `NSStatusItem` strongly are the three failure modes that, if encountered late, require significant rework. All three are avoidable with correct upfront setup. Defer drag-to-reorder and configurable hotkey to v1.x — both have known SwiftUI implementation friction that shouldn't block shipping the core value.

---

## Key Findings

### Recommended Stack

The stack is intentionally minimal. Swift 6.1 with `@Observable` (macOS 14+) eliminates the need for Combine. AppKit is required only for `NSStatusItem` and `NSPanel` — everything inside the panel is SwiftUI. Two SPM libraries handle the only genuinely complex integrations: `KeyboardShortcuts 2.4.0` (sindresorhus) for the global hotkey (App Store sandbox-compatible, user-configurable, ships with a SwiftUI recorder component) and `Defaults 9.0.6` (sindresorhus) for type-safe UserDefaults wrapping of preferences. Task data is stored as JSON in `~/Library/Application Support/QuickTask/tasks.json` via `Codable` + `FileManager` — no Core Data, no SQLite, no cloud.

**Core technologies:**
- Swift 6.1 (Xcode 16.3): Primary language — Swift 6 concurrency with `@MainActor` annotations is the correct model for UI-touching AppKit/SwiftUI bridge code
- SwiftUI (macOS 14+ API surface): All panel UI — `@Observable`, `List`, `Toggle`, animations; clean declarative model fits checklist perfectly
- AppKit NSStatusItem: Menu bar icon and entry point — required because `MenuBarExtra` cannot be programmatically toggled from a global hotkey
- AppKit NSPanel (subclassed): Floating panel window — `.nonactivatingPanel` + `.floatingWindowLevel` + `canBecomeKey = true` is the Spotlight-style pattern
- KeyboardShortcuts 2.4.0 (SPM): Global hotkey — sandbox-compatible, persists user shortcut to UserDefaults, includes recorder UI
- Defaults 9.0.6 (SPM): Preferences storage — type-safe, Codable-aware, SwiftUI property wrapper support
- JSON + FileManager: Task persistence — idiomatic macOS pattern; no overhead; easy to inspect and back up

**What not to use:** `MenuBarExtra(.window)` for the primary approach, `NSWindow` instead of `NSPanel`, `UserDefaults` for task list storage, Combine (replaced by `@Observable`), Core Data, any third-party UI framework.

### Expected Features

Research confirms users expect all of the following table stakes from day one, and that the differentiated UX position (completed tasks fade but persist) is the right call — ToDoBar auto-hides completed tasks and it's the right contrast point.

**Must have (table stakes — v1):**
- Global hotkey to open panel — competitors who lack this get explicit user complaints; the entire product brief centers on this
- Type task + Return to capture — two keystrokes to commit; text field auto-focused on open
- Checklist with checkboxes — SwiftUI `List` + `Toggle`; visually clear checked/unchecked state
- Completed tasks fade but persist — strikethrough + opacity; QuickTask's UX identity; distinct from competitors
- Escape / click-outside to dismiss panel — standard floating panel behavior users expect
- Delete tasks — required escape valve; completed tasks that persist need manual clearing
- Launch at login (opt-in) — utility that vanishes on reboot is not a utility; use `SMAppService`
- Local file persistence — tasks survive quit and restart

**Should have (competitive differentiators — v1.x):**
- Task count badge on menu bar icon — at-a-glance active task count
- Drag-to-reorder — priority control; implement with drag handles to avoid SwiftUI text-field conflict
- Configurable hotkey — user muscle memory; `KeyboardShortcuts` recorder UI makes this straightforward
- Bulk-clear completed tasks — "Clear all done" button; needed once completed list accumulates

**Defer (v2+):**
- Optional due date (single date, no recurrence)
- Spotlight-style panel aesthetic upgrade (custom NSPanel as aesthetic enhancement if v1 uses popover)
- Keyboard shortcut to mark task complete (Space bar on selected row)
- Plain text export / copy to clipboard

**Never build:** Cloud sync, multiple lists/projects, tags/priorities, reminders/notifications, Markdown in tasks, menubar text display of current task.

### Architecture Approach

The architecture has five clear layers with explicit component boundaries and a strict dependency direction: disk -> `FileStore` -> `TaskRepository` -> `TaskStore` -> SwiftUI views. The `FloatingPanel` (NSPanel subclass) is an independent AppKit layer that hosts SwiftUI via `NSHostingView`. `HotkeyService` wires to `PanelManager` via a singleton pattern, which is appropriate for this single global concern. All writes go through-to-disk synchronously on every mutation — acceptable for <500 tasks; add background queue for larger datasets.

**Major components:**
1. `NSStatusItem` + `AppDelegate` — menu bar icon; must be strongly retained for lifetime of app
2. `FloatingPanel` (NSPanel subclass) — floating window with `.nonactivatingPanel`, `canBecomeKey = true`, `resignKey()` returning focus to previous app
3. `HotkeyService` — global keyboard event registration via `KeyboardShortcuts` SPM; fires `PanelManager.shared.toggle()`
4. `TaskStore` (`ObservableObject`) — single source of truth; `@Published var tasks: [Task]`; injected as `@EnvironmentObject`
5. `TaskRepository` / `FileStore` — CRUD logic and JSON persistence; `FileStore` is deliberately dumb (no business logic)
6. SwiftUI views (`ContentView`, `TaskInputView`, `TaskListView`, `TaskRowView`) — all UI inside the panel; never touch `FileStore` directly

**Build order (enforced by dependencies):** `Task` model -> `FileStore` -> `TaskRepository` -> `TaskStore` -> SwiftUI views -> `FloatingPanel` (parallel) -> `HotkeyService` -> App entry point wiring.

### Critical Pitfalls

These are the pitfalls with the highest recovery cost if discovered late. All six of the critical pitfalls identified in research concentrate in Phase 1.

1. **SwiftUI `.keyboardShortcut()` does not fire when app is in background** — use `KeyboardShortcuts` SPM (Carbon/CGEventTap under the hood); never use `.keyboardShortcut()` for the capture trigger; verify by testing while Safari is focused
2. **NSPanel subclass is required — skip it and floating behavior, focus management, and dismissal all break** — 50 lines upfront saves days of debugging; `NSWindow` steals focus; `MenuBarExtra(.window)` cannot be programmatically toggled
3. **Activation policy causes panel to open behind other apps** — use `.nonactivatingPanel` + `canBecomeKey = true` + `panel.makeKey()` (not `makeKeyAndOrderFront`); override `resignKey()` to return focus to previous app
4. **NSStatusItem disappears if not strongly retained** — store on `AppDelegate` or a long-lived `@Observable` object; ARC will silently deallocate a local or weak reference
5. **Wrong permission API (Accessibility vs Input Monitoring)** — use `CGEventTap` with `.listenOnly` option or `KeyboardShortcuts` library; Accessibility is not reliably grantable in sandboxed/App Store apps; `KeyboardShortcuts` handles this correctly internally
6. **`SettingsLink` / `openSettings()` silently fail in menu bar context** — requires a hidden zero-size `Window` scene declared first in the `App` body, plus activation policy juggling; plan ~50 lines of boilerplate for what Apple implies is a one-liner

---

## Implications for Roadmap

Based on combined research, all critical pitfalls are front-loaded in Phase 1, the data model is simple and well-understood, and the UI layer has no complex interactions at v1 (drag-to-reorder is correctly deferred). A three-phase v1 roadmap is appropriate, with a natural v1.x extension phase for post-validation features.

### Phase 1: App Shell, Hotkey, and Floating Panel

**Rationale:** Every critical pitfall from PITFALLS.md is a Phase 1 concern. The NSPanel subclass, activation policy, NSStatusItem retention, and global hotkey permission model must all be correct before any UI or data work begins. Getting this wrong and discovering it in Phase 2 or 3 is the highest-cost recovery path in the entire project. This phase has no UI beyond a placeholder — it is purely the structural scaffolding.

**Delivers:** Running macOS app with menu bar icon, floating panel that opens/closes on global hotkey, panel dismisses on Escape/click-outside, focus returns to previous app on dismiss, NSStatusItem persists reliably.

**Features addressed (FEATURES.md):** Global hotkey, click menu bar icon to open/close, dismiss on Escape/click-outside.

**Pitfalls to prevent (PITFALLS.md):** Pitfalls 1-3 and 5 (hotkey API, panel subclass, activation policy, permission model), Pitfall 5 (NSStatusItem retention).

**Stack elements:** NSStatusItem, NSPanel subclass, KeyboardShortcuts SPM 2.4.0, AppDelegate pattern, `LSUIElement = YES` in Info.plist.

### Phase 2: Task Data Model, Persistence, and Core Capture UI

**Rationale:** Once the panel scaffold is proven, build the data layer bottom-up (Task model -> FileStore -> TaskRepository -> TaskStore) then wire to SwiftUI views. This order enforces the architecture's dependency direction and keeps the view layer thin from day one. The checklist UI and task capture are table stakes — ship nothing to users without them.

**Delivers:** Full task capture flow — hotkey opens panel, user types task, Return adds it to the checklist, tasks persist across restarts, checkbox marks complete with fade, delete removes tasks.

**Features addressed (FEATURES.md):** Return to add task, checklist with checkboxes, completed tasks fade + persist, delete tasks, local file persistence.

**Pitfalls to prevent (PITFALLS.md):** Anti-pattern of writing to disk in view body (views call TaskStore, not FileStore), UserDefaults for task list (use JSON in Application Support), deleting completed tasks immediately (set `isCompleted = true`, animate opacity).

**Architecture components:** `Task` model, `FileStore`, `TaskRepository`, `TaskStore`, `TaskInputView`, `TaskListView`, `TaskRowView`.

### Phase 3: Settings, Launch at Login, and v1 Polish

**Rationale:** Launch-at-login is a table stakes feature but uses `SMAppService` which has no dependency on the data layer, so it's correctly deferred to Phase 3. The Settings window has the most implementation gotchas (Pitfall 4: `SettingsLink` silent failure requiring the hidden `Window` scene workaround) and should be planned with that boilerplate in mind. Polish — empty state, animations, icon design — completes the v1 feature set.

**Delivers:** Opt-in launch at login, Settings window with at minimum a launch-at-login toggle and hotkey documentation, empty state encouragement ("All clear."), smooth panel open/close animation, correct app icon (template image for menu bar).

**Features addressed (FEATURES.md):** Launch at login (opt-in), empty state, smooth open/close animation.

**Pitfalls to prevent (PITFALLS.md):** Pitfall 4 (`SettingsLink` hidden window workaround), `SMAppService` status queried at runtime (not stored locally), Input Monitoring onboarding screen before system prompt fires.

**Stack elements:** `SMAppService`, Defaults SPM 9.0.6 for preferences, activation policy juggling for Settings window.

### Phase 4 (v1.x): Post-Validation Enhancements

**Rationale:** These features have known implementation friction or are best prioritized after real user feedback. None are blocking for v1 delivery; all require the Phase 1-3 foundation to be complete.

**Delivers:** Task count badge on menu bar icon, drag-to-reorder with hover drag handles (avoiding SwiftUI text-field conflict), configurable hotkey via `KeyboardShortcuts.Recorder`, bulk-clear completed tasks button.

**Features addressed (FEATURES.md):** Task count badge, drag-to-reorder, configurable hotkey, bulk-clear completed.

**Note on drag-to-reorder:** SwiftUI's `onMove` adds a global drag gesture that delays text-field tap-to-focus. Use drag handles visible on hover and `moveDisabled()` on text-field rows. Plan implementation time accordingly — this is a known SwiftUI/macOS friction point documented in research.

### Phase Ordering Rationale

- **Pitfall concentration in Phase 1** drives the front-loading: all six critical pitfalls either occur in Phase 1 or require Phase 1 architecture decisions that cannot be retrofitted. This is the non-negotiable ordering constraint.
- **Data before UI** in Phase 2 enforces the architecture's dependency direction and keeps the view layer thin from day one, making the data layer independently testable.
- **Settings deferred to Phase 3** because the `SettingsLink` workaround (Pitfall 4) requires careful planning but is not a blocker for the core task capture experience.
- **v1.x features deferred** because drag-to-reorder conflicts with text-field focus (known friction), configurable hotkey requires a Settings UI (Phase 3 dependency), and the count badge + bulk-clear are enhancements users request after seeing a real task list.

### Research Flags

Phases with well-documented patterns (skip `/gsd:research-phase`):
- **Phase 1:** NSPanel + KeyboardShortcuts patterns are extensively documented in Cindori blog, Multi.app blog, and official library READMEs. Follow the documented pattern exactly.
- **Phase 2:** Codable + FileManager JSON persistence is a standard macOS pattern with no ambiguity. `ObservableObject` + `@EnvironmentObject` is well-established.
- **Phase 3:** `SMAppService` usage is well-documented (nil coalescing blog). Settings window workaround is fully described in Steipete's 5-hour journey post.

Phases that may benefit from targeted research during planning:
- **Phase 4 (drag-to-reorder):** The SwiftUI `onMove` + text-field conflict workaround is documented but implementation-specific. If this becomes a priority, research the specific drag handle pattern before planning.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Apple framework facts verified against official docs; library versions verified on GitHub; MenuBarExtra limitation confirmed by Apple feedback report |
| Features | MEDIUM | Table stakes verified across multiple competitor products and user reviews; some UX positioning inferred from category patterns |
| Architecture | MEDIUM-HIGH | NSPanel pattern verified across multiple practitioner blogs consistent with Apple docs; component boundaries are standard MVVM for this app type |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls verified against official docs, Apple Developer Forums, and practitioner posts; all claims cross-referenced with at least two sources |

**Overall confidence: MEDIUM-HIGH**

The stack and architecture are well-understood for this domain. The main uncertainty is in UX positioning (how users will respond to "completed tasks fade but persist" vs. alternatives), which is a product decision rather than a technical one and should be validated through use.

### Gaps to Address

- **macOS notch hiding of menu bar icon:** No API exists to detect if the icon is hidden by the MacBook notch. Document the Application Support path for users who need to manage storage; recommend Bartender/Ice as a user option. No technical mitigation available.
- **Default hotkey selection:** Research confirms the default must avoid Cmd+Space (Spotlight), Cmd+Shift+3/4/5 (screenshots), and Mission Control shortcuts. Recommended default: `Cmd+Shift+Space` or `Ctrl+Option+Space`. Validate against system shortcut list during Phase 1.
- **App Store vs. direct distribution decision:** The stack is App Store-compatible with no changes needed. The decision affects marketing, pricing, and review timeline but not the technical approach. Can be deferred until after v1 is complete.
- **Performance threshold for async writes:** Research recommends synchronous writes for <500 tasks. If users with large task lists report stutter, the fix is a single `DispatchQueue.global(qos: .background)` dispatch — well-understood and easy to add.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Docs — NSPanel: https://developer.apple.com/documentation/appkit/nspanel
- Apple Developer Docs — NSEvent monitoring: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html
- Apple SwiftUI — MenuBarExtra (macOS Ventura+): https://developer.apple.com/documentation/SwiftUI/MenuBarExtra
- sindresorhus/KeyboardShortcuts GitHub — v2.4.0, macOS 10.15+, App Store sandbox-compatible: https://github.com/sindresorhus/KeyboardShortcuts/releases
- sindresorhus/Defaults GitHub — v9.0.6, macOS 11+: https://github.com/sindresorhus/Defaults/releases
- Swift.org — Swift 6.1 released March 31, 2025: https://www.swift.org/blog/swift-6.1-released/
- Apple Feedback FB11984872 — MenuBarExtra cannot programmatically hide/show window: https://github.com/feedback-assistant/reports/issues/383

### Secondary (MEDIUM confidence)
- Cindori Developer Blog — Floating panel implementation + MenuBarExtra limitations: https://cindori.com/developer/floating-panel
- Multi.app blog — Nailing activation behavior of Spotlight/Raycast-like panels: https://multi.app/blog/nailing-the-activation-behavior-of-a-spotlight-raycast-like-command-palette
- Peter Steinberger (Steipete) — Showing Settings from macOS menu bar items: https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items
- Markus Bodner — Spotlight-like NSPanel with SwiftUI: https://www.markusbodner.com/til/2021/02/08/create-a-spotlight/alfred-like-window-on-macos-with-swiftui/
- NilCoalescing — macOS menu bar utility in SwiftUI: https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/
- NilCoalescing — Launch at Login with SMAppService: https://nilcoalescing.com/blog/LaunchAtLoginSetting/
- NilCoalescing — List reordering with editable items: https://nilcoalescing.com/blog/ListReorderingWhileStillBeingAbleToEditTheListItems/
- jano.dev — Accessibility permission in macOS (CGEventTap permission modes): https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html
- artlasovsky.com — Fine-tuning macOS app activation behavior: https://artlasovsky.com/fine-tuning-macos-app-activation-behavior
- Apple Developer Forums — Accessibility vs Input Monitoring permission model: https://developer.apple.com/forums/thread/707680
- Apple Developer Forums — Global hotkeys on macOS (CGEventTap vs NSEvent): https://developer.apple.com/forums/thread/735223

### Tertiary (MEDIUM-LOW confidence)
- ToDoBar App Store reviews — user requests for global hotkey, complaints about reorder UX: https://apps.apple.com/us/app/todobar-tasks-on-your-menu-bar/id6470928617
- ToDoBar GitHub — feature philosophy: https://github.com/menubar-apps/ToDoBar
- PopDo product page — Reminders integration, iCloud sync: https://ds9soft.com/popdo/
- Things 3 Quick Entry documentation — global hotkey, ⌃Space: https://culturedcode.com/things/support/articles/2249437/
- Jesse Squires — MacBook notch and menu bar fixes: https://www.jessesquires.com/blog/2023/12/16/macbook-notch-and-menu-bar-fixes/

---

*Research completed: 2026-02-17*
*Ready for roadmap: yes*
