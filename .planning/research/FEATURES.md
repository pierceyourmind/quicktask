# Feature Research

**Domain:** macOS menu bar quick-capture task / checklist app
**Researched:** 2026-02-18 (updated for v1.1 milestone)
**Confidence:** HIGH for v1.1 features (multiple verified sources); MEDIUM for competitive analysis

---

## v1.1 Target Features: Expected Behaviors

This section documents the precise expected behaviors for the four features being added in v1.1. These were previously identified as P2 (v1.x) features. Behaviors are described from the user's perspective — what they expect to see and how they expect these features to work in the macOS menu bar app category.

### Task Count Badge on Menu Bar Icon

**What users expect:**
- The menu bar icon shows a number indicating how many incomplete (unchecked) tasks exist
- Badge updates immediately when a task is added, checked, or deleted — no lag
- Badge disappears (or shows nothing) when the task list is empty — not "0", just the plain icon
- Completed tasks do NOT count toward the badge — only active (unchecked) tasks
- The badge is readable in both light and dark menu bar modes (template image + drawn text handles this automatically)

**Implementation approach (HIGH confidence):**
- Use SF Symbols: `NSImage(systemSymbolName: "\(count).circle", ...)` works for counts 0-50, which covers realistic task list sizes
- For counts above 50 (edge case), draw text onto the template icon using `NSImage` with `draw(_:in:)` — pattern is well documented in AppKit
- Simpler approach for small counts: set `statusItem.button?.title = "\(count)"` alongside the image; AppKit auto-positions the title
- The `NSStatusBarButton` `image` + `title` combination is the standard approach: image = icon, title = count string
- Template images (black + clear only) automatically adapt to Dark Mode — use this, not colored images

**Design calls that need a decision:**
- Show nothing vs. show "0" when empty: convention is show nothing (just the icon) — see Things 3, Fantastical
- Superscript badge style vs. text-alongside-icon: text alongside is far simpler and readable; superscript requires custom drawing

**Complexity:** LOW. Setting a string on `NSStatusBarButton.title` or swapping an SF Symbol image is a one-liner once the data binding is in place.

---

### Drag-to-Reorder Tasks

**What users expect:**
- Grab a row by a drag handle (a grip icon, typically six dots or three lines) and drag it to a new position
- The list reorders in real time as you drag; other rows shift to make room
- Releasing drops the row at the current position — it does not snap back
- Only active (incomplete) tasks should be reorderable; or all tasks reorder as a group — either is acceptable, but completed tasks drifting to the top feels wrong
- The sort order persists across app restarts
- Reorder does NOT require a special "edit mode" toggle (unlike iOS); on macOS it's expected to be always available via drag handle hover

**The critical implementation constraint (HIGH confidence — verified at nilcoalescing.com):**
SwiftUI's `List` `.onMove()` modifier installs a gesture recognizer that adds a delay to all row interactions, including taps on text fields and checkboxes. This delay makes checkboxes feel sluggish and is unacceptable in a task app. The solution is:
1. Use `moveDisabled(true)` on every row by default
2. Show a drag handle icon on row hover (`.onHover`)
3. Set `moveDisabled(!isHoveringDragHandle)` — only the handle region enables dragging
4. The hover state persists through the drag gesture, so the drag completes cleanly

**The `sortOrder` field is required:**
The task data model must have a stable `sortOrder` (or `index`) field. JSON array order is not reliable as a sort key once concurrent writes and deletions happen. Add `sortOrder: Int` to the task model before implementing reorder. This is the only data model dependency.

**Completed task interaction:**
Decided by UX intent: since completed tasks are faded at the bottom, they can be excluded from reordering (`moveDisabled(task.isCompleted)`). Active tasks sort among themselves; completed tasks accumulate below.

**Complexity:** MEDIUM. The `.onMove` API is simple, but the drag-handle + `moveDisabled` hover pattern requires careful state management, and `sortOrder` persistence must be wired through the storage layer.

---

### Configurable Hotkey

**What users expect (macOS convention):**
- A "Keyboard Shortcut" field in Preferences/Settings where they click and type a new shortcut
- The field shows the current shortcut in human-readable form (e.g., "⌘⇧Space")
- While the field is active/recording, pressing a key combo immediately shows it in the field
- If the shortcut conflicts with a system shortcut or another app shortcut, a warning appears — the field does not silently ignore it
- A "Clear" button (×) lets them remove the shortcut entirely
- The shortcut takes effect immediately — no "Save" button required
- Shortcut preference survives app restarts (stored in UserDefaults)

**Library: KeyboardShortcuts by sindresorhus (HIGH confidence — verified against GitHub)**
- Version 2.4.0 (September 2025), MIT license, Swift Package Manager
- Mac App Store and sandbox compatible — no special entitlements required
- `KeyboardShortcuts.Recorder` is a SwiftUI `View` — drop it into a SwiftUI settings form
- Handles UserDefaults storage automatically (no manual persistence code)
- Handles system conflict detection and displays warnings automatically
- Provides clear (×) button built in
- Works even when the app's menu is open — critical for a menu bar app
- `KeyboardShortcuts.onKeyDown(for: .openPanel) { }` replaces the manual `NSEvent.addGlobalMonitorForEvents` pattern

**Settings UI placement:**
- Add a "Preferences" / "Settings" window (standard macOS `Settings` scene in SwiftUI or `NSPanel`)
- The recorder sits in a `Form` with a label: `KeyboardShortcuts.Recorder("Open QuickTask:", name: .openPanel)`
- Standard macOS Settings window (⌘,) is the expected location — not buried in a menu item

**Migration from hardcoded hotkey:**
- Define a `KeyboardShortcuts.Name` (e.g., `.openPanel`) with a default value of the existing `Cmd+Shift+Space`
- On first launch after update, the stored UserDefaults key won't exist — the default fires, so behavior is unchanged for existing users

**Complexity:** MEDIUM. The library removes most complexity, but a Settings window/panel must be added to the app, and the existing manual `CGEventTap` / `NSEvent` global monitor must be removed and replaced with the library's mechanism.

---

### Bulk-Clear Completed Tasks

**What users expect:**
- A single action (button or menu item) that removes all checked tasks at once
- The action is labeled clearly: "Clear Completed", "Remove Done", or similar — not "Delete All"
- The button only appears / is only enabled when at least one completed task exists
- No confirmation dialog for this action (it is reversible implicitly: the tasks are already "done"; the UX contract of fading completed tasks signals they are soft-deleted)
- The action is fast — all completed tasks disappear in one animated batch
- The action does NOT affect active (unchecked) tasks

**Placement conventions (from competitor analysis):**
- Footer of the task panel, right-aligned or centered below the list — matches the "Clear All" position in Reminders and similar apps
- Alternatively, a contextual menu item on right-click of the panel — less discoverable but cleaner
- Footer button is strongly preferred for discoverability in a panel UI

**Design constraint — "deliberately minimal" project value:**
The button should appear only when there are completed tasks. When all tasks are active, the footer should be empty or very subtle (no button). This avoids cluttering the minimal panel UI with a button that is irrelevant most of the time.

**Interaction with completed task persistence:**
This app deliberately retains completed tasks (faded) rather than auto-deleting them. Bulk-clear is the intentional escape valve for that policy — users accumulate done items, then clear them in batch when they choose. This makes bulk-clear a first-class feature, not an afterthought.

**Complexity:** LOW. Filter `tasks.filter { !$0.isCompleted }`, save, animate removal. The only complexity is the conditional visibility of the button and the batch animation.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Global hotkey to open panel | Every competing app (Things 3, Todoist, Drafts) offers this; ToDoBar users explicitly complained its absence blocks adoption | LOW | Requires `CGEventTap` / `NSEvent` global monitor; well-documented Swift pattern. Configurable preferred; one sensible default is acceptable at v1 |
| Type task + Return to capture | Core UX contract of the category. Anything slower than two keystrokes to commit a task is friction | LOW | Text field must be focused on panel open, Return saves and clears field, ready for next entry |
| Checklist with checkboxes | Users come for a list — rows with check state is the minimum legible UI | LOW | SwiftUI `List` + `Toggle`/custom checkbox; visual state must be clear (checked vs unchecked) |
| Click menu bar icon to open/close | Standard macOS menu bar extra behavior; users try clicking the icon before anything else | LOW | `NSStatusItem` + `NSPopover`; left-click toggles popover |
| Launch at login | A utility that vanishes on reboot is not a utility | LOW | `SMAppService` (macOS 13+) or `LaunchAtLoginHelper`; must default to OFF per App Store review rules, user opts in |
| Persist tasks across restarts | State survival across quit/restart is a baseline expectation for anything called a "task" app | LOW | Local file storage (JSON to `~/Library/Application Support/` or `UserDefaults`); no cloud required |
| Dismiss panel on Escape or click-outside | Standard floating panel behavior; users expect it because Spotlight, Alfred, and Raycast all do this | LOW | `NSPanel` with `becomesKeyOnlyIfNeeded` handles click-outside; `onExitCommand` handles Escape in SwiftUI |
| Delete / remove tasks | Users need to purge items; a list that only grows is useless | LOW | Swipe-to-delete or a delete button on hover; both are acceptable patterns |
| Completed tasks visually distinct | Strikethrough or dimmed text signals "done" without requiring immediate deletion | LOW | SwiftUI strikethrough modifier + opacity; standard UX pattern across Reminders, Things, TickTick |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Completed tasks fade but persist (project design decision) | Satisfying "done" signal without loss of record; users who defer cleanup feel safe. Distinct from competitors that either auto-delete (ToDoBar) or show clutter | LOW | Opacity animation on check; persist in storage with `isCompleted` flag; visual separation from active tasks |
| Spotlight-style panel appearance | Familiar, focused, elegant interaction model | MEDIUM | Requires custom `NSPanel` subclass; centered on screen, drop shadow, rounded corners |
| Keyboard-only workflow (no mouse required) | Power users want to capture without touching the trackpad | LOW | Focus management: panel opens → text field auto-focused → Return saves → field clears → Escape closes |
| Drag-to-reorder tasks | Priority changes without delete/re-add cycle. Competitors like ToDoBar have clunky arrow buttons | MEDIUM | SwiftUI `List` `.onMove()` + drag-handle hover pattern required to prevent gesture conflict with checkboxes |
| Configurable hotkey | Users have their own muscle memory; one hard-coded hotkey alienates users whose shortcut conflicts | MEDIUM | `KeyboardShortcuts` library (sindresorhus, v2.4.0); handles storage, conflict detection, and recorder UI |
| Task count badge on menu bar icon | At-a-glance "how many open tasks" without opening the panel | LOW | `NSStatusBarButton` title string or SF Symbol numbered icon; active tasks only; hide when count is 0 |
| Bulk-clear completed tasks | One-tap escape valve for the "fade but persist" design — keeps the list from accumulating forever | LOW | Conditional footer button; filter + save + animate; only visible when completed tasks exist |
| Empty state encouragement | First-run and zero-task states should feel inviting, not empty | LOW | Placeholder text in input ("What's on your mind?"), zero-task message ("All clear.") |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Cloud sync / iCloud | Users want tasks on iPhone | Destroys "local file, no account, zero friction" core value; adds entitlements, sign-in flow, conflict resolution, network dependency | Be explicit: "This app is intentionally local. For sync, use Reminders or Things." |
| Subtasks / nested tasks | Power users always want more hierarchy | Checklist grows into a project manager; UI collapses under its own weight | Keep it flat. Complex tasks belong in OmniFocus or Things |
| Reminders / notifications / due dates | Every task app review mentions "wish it had reminders" | Requires notification permissions, background daemon, scheduling; fundamentally changes app from scratchpad to scheduler | Out of scope. If added later, limit to single optional due date + macOS notification, no recurring logic |
| Multiple lists / projects | Users with lots of tasks want organization | Adds list-management UI, context switching, cross-list logic; kills "one-place" simplicity | Single flat list is a feature, not a bug |
| Tags / labels / priorities | GTD-style organization | Tag management + filter UI + priority sorting = a different app | Completed visual state + manual drag-to-reorder are sufficient |
| Markdown in tasks | Developers love markdown everywhere | Task titles are one-line; rich formatting irrelevant at that granularity; adds parsing | Plain text only |
| Menubar text display of current task | Show "Task name" in menu bar like ToDoBar | Eats menu bar real estate; conflicts with other apps; very limited space on laptops | Count badge instead — less intrusive, equally informative |
| Auto-clear completed tasks | Reduce clutter automatically | Removes user agency; can surprise users who wanted to review done items | Bulk-clear button (user-initiated) respects the "fade but persist" design contract |
| Undo for bulk-clear | "Accidentally cleared" concerns | Adds undo stack complexity to a minimal app; completed tasks are already "done" — loss is low | Show count of cleared tasks briefly ("Cleared 5 tasks") so user knows what happened |

---

## Feature Dependencies

```
[Global hotkey] ──requires──> [Panel open/close logic]
                                    └──requires──> [NSStatusItem setup]

[Task capture (Return to add)]
    └──requires──> [Task data model + storage]
                       └──requires──> [Local file persistence]

[Checklist with checkboxes]
    └──requires──> [Task data model + storage]

[Completed tasks fade + persist]
    └──requires──> [Checklist with checkboxes]
    └──enables──> [Bulk-clear completed] (accumulation makes bulk-clear valuable)

[Drag-to-reorder]
    └──requires──> [Checklist with checkboxes]
    └──requires──> [sortOrder field in data model]
    └──conflicts──> [checkbox tap / text field focus] (drag-handle hover workaround required)

[Task count badge]
    └──requires──> [Task data model + storage]
    └──enhances──> [NSStatusItem setup]

[Configurable hotkey]
    └──requires──> [Global hotkey (to replace)]
    └──requires──> [Settings window/panel]
    └──replaces──> [Manual NSEvent global monitor]

[Bulk-clear completed]
    └──requires──> [Checklist with checkboxes]
    └──requires──> [Completed tasks persist] (if auto-deleted, no bulk-clear needed)
    └──enhances──> [Completed tasks fade + persist] (provides the exit path for that design)
```

### Dependency Notes

- **Global hotkey requires panel logic:** The hotkey's only job is to toggle the panel; panel must exist before hotkey does anything meaningful.
- **All display features require data model:** Task data model (id, title, isCompleted, sortOrder, createdAt) must be defined before checklist, badge, or fade features can be built.
- **Drag-to-reorder requires sortOrder field:** The data model must have an explicit `sortOrder: Int` field before reorder can be persisted. This is the only data model change needed for v1.1.
- **Drag-to-reorder conflicts with interactive row elements:** SwiftUI `onMove` adds a global gesture delay. Use drag-handle + `moveDisabled(!isHovering)` pattern — verified solution.
- **Configurable hotkey is a settings UI dependency:** It requires a Preferences window (`Settings` scene). Plan this as a prerequisite, not an afterthought.
- **Bulk-clear depends on "fade but persist" design:** If completed tasks were auto-deleted, bulk-clear would be irrelevant. The existing "fade but persist" UX creates the need for a manual batch-clear escape valve.

---

## MVP Definition

### Already Shipped (v1)

- [x] **NSStatusItem + NSPanel** — the container
- [x] **Global hotkey (Cmd+Shift+Space hardcoded)** — primary entry point
- [x] **Auto-focus text field on panel open** — keyboard-first capture
- [x] **Return to add task** — single keystroke commit
- [x] **Checklist with checkboxes** — core display and interaction
- [x] **Completed tasks fade + persist (strikethrough + opacity)** — UX identity
- [x] **Escape / click-outside to close panel** — standard dismissal
- [x] **Delete tasks** — required escape valve
- [x] **Local file persistence** — tasks survive quit/restart

### Target for v1.1

- [ ] **Task count badge on menu bar icon** — LOW complexity, HIGH discoverability value; show active task count, hide when 0
- [ ] **Drag-to-reorder** — MEDIUM complexity; requires `sortOrder` data model field + drag-handle hover pattern
- [ ] **Configurable hotkey** — MEDIUM complexity; `KeyboardShortcuts` library + Settings window; migrate from manual event monitor
- [ ] **Bulk-clear completed** — LOW complexity; conditional footer button; filter + save + animate

### Future Consideration (v2+)

- [ ] **Optional due date field** — single date, no recurrence; only if user research shows demand
- [ ] **Spotlight-style panel (custom NSPanel)** — aesthetic upgrade
- [ ] **Keyboard shortcut to mark task complete** — Space bar on selected row; power-user feature
- [ ] **Plain text export / copy to clipboard** — simple interop; low value until users have many tasks

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Global hotkey | HIGH | LOW | P1 (done) |
| Return to add task | HIGH | LOW | P1 (done) |
| Checklist with checkboxes | HIGH | LOW | P1 (done) |
| Completed tasks fade + persist | HIGH | LOW | P1 (done) |
| Local file persistence | HIGH | LOW | P1 (done) |
| Launch at login | HIGH | LOW | P1 (done) |
| Escape / click-outside dismiss | HIGH | LOW | P1 (done) |
| Delete tasks | HIGH | LOW | P1 (done) |
| Task count badge | MEDIUM | LOW | P2 (v1.1) |
| Drag-to-reorder | MEDIUM | MEDIUM | P2 (v1.1) |
| Configurable hotkey | MEDIUM | MEDIUM | P2 (v1.1) |
| Bulk-clear completed | MEDIUM | LOW | P2 (v1.1) |
| Spotlight-style panel | MEDIUM | MEDIUM | P3 |
| Due date (optional) | MEDIUM | HIGH | P3 |
| Plain text export | LOW | LOW | P3 |
| Cloud sync | LOW | HIGH | Never |
| Multiple lists | LOW | HIGH | Never |
| Tags / priorities | LOW | MEDIUM | Never |

**Priority key:**
- P1: Must have for launch (all shipped in v1)
- P2: Should have, add when possible (v1.1 target)
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | ToDoBar | Things 3 (menu bar) | MonkeyMind | QuickTask v1.1 approach |
|---------|---------|---------------------|------------|------------------------|
| Global hotkey | No (users complained) | Yes (⌃Space, configurable) | Not documented | Yes — now configurable via `KeyboardShortcuts` |
| Quick capture text field | Yes | Yes | Yes | Yes — auto-focused on open |
| Checklist | Yes | Yes | Yes | Yes |
| Completed task behavior | Auto-hide (v2.0) | Delete | Auto-delete option | Fade + persist; bulk-clear button |
| Drag to reorder | No (clunky arrows) | Yes | Not documented | v1.1 — drag handle + `.onMove` |
| Count badge | Shows current task text | No | No | v1.1 — active task count, hide when 0 |
| Bulk-clear | Auto-hide toggle | N/A (auto-delete) | Auto-delete toggle | v1.1 — manual "Clear Completed" footer button |
| Configurable hotkey | No | Yes | Not documented | v1.1 — full recorder UI |
| Cloud / sync | No (local only) | iCloud | iCloud | No (intentionally local) |

---

## Sources

- KeyboardShortcuts library (sindresorhus, v2.4.0, verified February 2026): https://github.com/sindresorhus/KeyboardShortcuts
- SwiftUI drag-to-reorder + text field conflict pattern (nilcoalescing.com, verified February 2026): https://nilcoalescing.com/blog/ListReorderingWhileStillBeingAbleToEditTheListItems/
- NSStatusItem / NSStatusBarButton implementation (Apple Developer Documentation): https://developer.apple.com/documentation/appkit/nsstatusitem
- SwiftUI List `.onMove` documentation (Sarunw, verified): https://sarunw.com/posts/swiftui-list-onmove/
- ToDoBar App Store reviews (user requests for hotkey, complaints about reorder UX): https://apps.apple.com/us/app/todobar-tasks-on-your-menu-bar/id6470928617
- Things 3 Quick Entry documentation (global hotkey, autofill, ⌃Space): https://culturedcode.com/things/support/articles/2249437/
- macOS menu bar app hybrid SwiftUI/AppKit pattern (Medium, January 2026): https://medium.com/@p_anhphong/what-i-learned-building-a-native-macos-menu-bar-app-eacbc16c2e14
- macOS menu bar app ecosystem overview: https://macmenubar.com/

---
*Feature research for: macOS menu bar quick-capture task app (QuickTask)*
*Researched: 2026-02-18 (updated for v1.1 milestone)*
