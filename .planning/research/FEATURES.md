# Feature Research

**Domain:** macOS menu bar quick-capture task / checklist app
**Researched:** 2026-02-17
**Confidence:** MEDIUM — core table stakes verified across multiple competitor products and user reviews; some nuances based on patterns inferred from the category

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Global hotkey to open panel | Every competing app (Things 3, Todoist, Drafts) offers this; ToDoBar users explicitly complained its absence blocks adoption — "I would love a hotkey so I didn't have to move my mouse" | LOW | Requires `CGEventTap` / `NSEvent` global monitor; well-documented Swift pattern. Configurable preferred; one sensible default is acceptable at v1 |
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
| Completed tasks fade but persist (project design decision) | Satisfying "done" signal without loss of record; users who defer cleanup feel safe. Distinct from competitors that either auto-delete (ToDoBar) or show clutter | LOW | Opacity animation on check; persist in storage with `isCompleted` flag; visual separation from active tasks. This is QuickTask's specific UX position — make "done" feel good without friction |
| Spotlight-style panel appearance | Familiar, focused, elegant interaction model. Users associate this style with speed and precision | MEDIUM | Requires custom `NSPanel` subclass (not a standard popover), centered on screen, drop shadow, rounded corners. References: markusbodner.com tutorial, cindori.com floating panel article |
| Keyboard-only workflow (no mouse required) | Power users want to capture without touching the trackpad — open with hotkey, type task, Return, done, Escape. Everything in one gesture chain | LOW | Focus management is the key: panel opens → text field auto-focused → Return saves → field clears → Escape closes. All achievable in SwiftUI focus system |
| Drag-to-reorder tasks | Priority changes without delete/re-add cycle. Competitors like ToDoBar have clunky arrow buttons that users complain about | MEDIUM | SwiftUI `List` `.onMove()` modifier works; interaction conflict with text fields needs `moveDisabled()` + hover-based drag handle pattern |
| Configurable hotkey | Users have their own muscle memory; one hard-coded hotkey alienates users whose shortcut conflicts | MEDIUM | Requires recording a key combo; `KeyboardShortcuts` library (sindresorhus) is the standard Swift package for this |
| Task count badge on menu bar icon | At-a-glance "how many open tasks" without opening the panel | LOW | `NSStatusItem` button image/title with count; only show for active (unchecked) tasks; hide or show "0" is a design call |
| Empty state encouragement | First-run and zero-task states should feel inviting, not empty | LOW | Placeholder text in the task input ("What's on your mind?"), empty list illustration or message ("All clear.") |
| Smooth open/close animation | Menu bar panel slide-in feels polished; abrupt pop-in feels cheap | LOW | `NSPanel` `orderFront` with `NSAnimationContext`; or SwiftUI transition on the popover content |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Cloud sync / iCloud | Users want tasks on iPhone | Destroys the "local file, no account, zero friction" core value; adds entitlements, sign-in flow, error handling, conflict resolution, and network dependency to what should be a 200ms app | Be explicit: "This app is intentionally local. For sync, use Reminders or Things." |
| Subtasks / nested tasks | Power users always want more hierarchy | Checklist grows into a project manager; UI collapses under its own weight; complexity scales with every new feature | Keep it flat. If a task is complex enough to need subtasks, it belongs in OmniFocus or Things |
| Reminders / notifications / due dates | Every task app review mentions "wish it had reminders" | Requires notification permissions, background daemon, local notification scheduling; fundamentally changes the app from a scratchpad to a scheduler | Out of scope for v1. If added later, limit to a single optional due date + macOS notification, no recurring logic |
| Multiple lists / projects | Users with lots of tasks want organization | Adds list-management UI, context switching, and cross-list logic; kills the "one-place" simplicity that makes a menu bar app work | Single flat list is a feature, not a bug. Promote it as focus, not limitation |
| Tags / labels / priorities | GTD-style organization is appealing | Tag management UI + filter UI + priority sorting = a different app; complexity doubles for modest value in a quick-capture tool | Completed visual state (faded) and manual drag-to-reorder are sufficient prioritization tools |
| Markdown in tasks | Developers love markdown everywhere | Task titles are one-line; rich formatting is irrelevant at that granularity; adds parsing complexity | Plain text only. Clarity over formatting |
| Menubar text display of current task | Show "Task name" in menu bar like ToDoBar | Eating menu bar real estate is intrusive; conflicts with other apps; users on laptops have very limited space | Use a count badge (number of active tasks) instead — less intrusive, equally informative |
| iCloud or cloud backup of tasks | Users fear data loss | Cloud is a separate product category; local backup to `~/Library` is sufficient; users can back up with Time Machine | Document the storage location so users can include it in their own backups |
| Sync to Reminders / Calendars | Interop with native apps | Requires `EventKit` entitlements, Apple Reminders data model mapping, two-way sync conflict resolution; out of proportion for a lightweight tool | One-way export to clipboard (copy task list as plain text) covers 90% of the use case |

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
    └──enhances──> [Delete tasks] (user clears completed in bulk later)

[Drag-to-reorder]
    └──requires──> [Checklist with checkboxes]
    └──conflicts──> [text field inline edit] (need drag-handle workaround)

[Task count badge]
    └──requires──> [Task data model + storage]
    └──enhances──> [NSStatusItem setup]

[Configurable hotkey]
    └──requires──> [Global hotkey]
    └──requires──> [Preferences/settings UI]

[Launch at login]
    └──independent (SMAppService, no other feature dependency)
```

### Dependency Notes

- **Global hotkey requires panel logic:** The hotkey's only job is to toggle the panel; panel must exist before hotkey does anything meaningful.
- **All display features require data model:** Task data model (id, title, isCompleted, sortOrder, createdAt) must be defined before checklist, badge, or fade features can be built.
- **Completed fade requires checkboxes:** Cannot build the visual completion state until check/uncheck is working.
- **Drag-to-reorder conflicts with text field focus:** SwiftUI's `onMove` adds a global drag gesture that delays text field tap-to-focus. Use drag handles (visible on hover) and `moveDisabled()` on text-field rows to resolve. This is a known SwiftUI/macOS friction point — plan implementation time accordingly.
- **Configurable hotkey is a v1.x feature:** It requires a settings panel to record key combos. Acceptable to ship v1 with a sensible default (e.g., `⌃⌥Space`) and make it configurable later.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed for QuickTask to deliver on its core value ("zero-friction task capture").

- [x] **NSStatusItem + NSPopover/NSPanel** — the container; everything lives here
- [x] **Global hotkey (hardcoded default)** — the primary entry point; without it the app is just a menu bar icon you click
- [x] **Auto-focus text field on panel open** — captures the keyboard immediately; no mouse required
- [x] **Return to add task** — single keystroke commit
- [x] **Checklist with checkboxes** — the core display and interaction
- [x] **Completed tasks fade + persist (strikethrough + opacity)** — QuickTask's UX identity; do this right in v1
- [x] **Escape / click-outside to close panel** — standard dismissal
- [x] **Delete tasks** — required escape valve; completed tasks that persist need manual clearing
- [x] **Launch at login (opt-in setting)** — users who leave this off will forget the app exists
- [x] **Local file persistence** — tasks survive quit/restart

### Add After Validation (v1.x)

Features to add once v1 is in users' hands.

- [ ] **Task count badge on menu bar icon** — users ask for this once they have a real task list; easy to add
- [ ] **Drag-to-reorder** — users request priority control after using a flat list for a while; implement with drag handle to avoid SwiftUI text-field conflict
- [ ] **Configurable hotkey** — once users integrate the app into workflow, they want their own shortcut
- [ ] **Bulk-clear completed tasks** — "Clear all done" button; once completed tasks accumulate this becomes needed

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Optional due date field** — single date, no recurrence; only if user research shows demand
- [ ] **Spotlight-style panel (custom NSPanel)** — aesthetic upgrade; not blocking for v1 if popover is clean
- [ ] **Keyboard shortcut to mark task complete** — Space bar on selected row; nice power-user feature
- [ ] **Plain text export / copy to clipboard** — simple interop; low value until users have many tasks

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Global hotkey | HIGH | LOW | P1 |
| Return to add task | HIGH | LOW | P1 |
| Checklist with checkboxes | HIGH | LOW | P1 |
| Completed tasks fade + persist | HIGH | LOW | P1 |
| Local file persistence | HIGH | LOW | P1 |
| Launch at login | HIGH | LOW | P1 |
| Escape / click-outside dismiss | HIGH | LOW | P1 |
| Delete tasks | HIGH | LOW | P1 |
| Task count badge | MEDIUM | LOW | P2 |
| Drag-to-reorder | MEDIUM | MEDIUM | P2 |
| Configurable hotkey | MEDIUM | MEDIUM | P2 |
| Bulk-clear completed | MEDIUM | LOW | P2 |
| Spotlight-style panel | MEDIUM | MEDIUM | P2 |
| Due date (optional) | MEDIUM | HIGH | P3 |
| Plain text export | LOW | LOW | P3 |
| Cloud sync | LOW | HIGH | Never |
| Multiple lists | LOW | HIGH | Never |
| Tags / priorities | LOW | MEDIUM | Never |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | ToDoBar | PopDo | Things 3 (menu bar) | QuickTask approach |
|---------|---------|-------|---------------------|-------------------|
| Global hotkey | No (users complained) | Not documented | Yes (⌃Space, configurable) | Yes — v1 with hardcoded default |
| Quick capture text field | Yes | Yes | Yes | Yes — auto-focused on open |
| Checklist | Yes | Yes | Yes | Yes |
| Completed tasks behavior | Auto-hide (v2.0) | Sync to Reminders | Delete | Fade + persist (our differentiator) |
| Cloud / sync | No (local only) | iCloud via Reminders | iCloud | No (intentionally local) |
| Drag to reorder | No (clunky arrows) | Not documented | Yes | v1.x |
| Count badge | Menu bar shows current task | No | No | v1.x |
| Launch at login | Not documented | Not documented | Yes | Yes, v1 |
| Storage | Local (no upload) | iCloud / Reminders | iCloud | Local file, no cloud |
| Price model | One-time | Freemium | Standalone ($50) | TBD |

---

## Sources

- ToDoBar App Store reviews (user requests for global hotkey, complaints about reorder UX): https://apps.apple.com/us/app/todobar-tasks-on-your-menu-bar/id6470928617
- ToDoBar GitHub (feature philosophy — radical minimalism): https://github.com/menubar-apps/ToDoBar
- PopDo product page (Reminders integration, iCloud sync, priority, search): https://ds9soft.com/popdo/
- Things 3 Quick Entry documentation (global hotkey, autofill, ⌃Space): https://culturedcode.com/things/support/articles/2249437/
- Spotlight-style NSPanel SwiftUI implementation: https://www.markusbodner.com/til/2021/02/08/create-a-spotlight/alfred-like-window-on-macos-with-swiftui/
- Floating panel in SwiftUI for macOS (Cindori): https://cindori.com/developer/floating-panel
- SwiftUI drag-to-reorder + text field conflict workaround: https://nilcoalescing.com/blog/ListReorderingWhileStillBeingAbleToEditTheListItems/
- macOS menu bar app ecosystem overview: https://macmenubar.com/
- User complexity complaints in task apps (OmniFocus, 2Do): https://zapier.com/blog/best-mac-to-do-list-apps/
- DSFQuickActionBar (Spotlight-inspired macOS component): https://github.com/dagronf/DSFQuickActionBar

---
*Feature research for: macOS menu bar quick-capture task app (QuickTask)*
*Researched: 2026-02-17*
