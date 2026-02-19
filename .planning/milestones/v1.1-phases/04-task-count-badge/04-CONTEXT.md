# Phase 4: Task Count Badge - Context

**Gathered:** 2026-02-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Display the count of incomplete (unchecked) tasks as a plain number next to the menu bar icon. The badge hides when the count is zero, reverting to icon-only. No new task capabilities — this phase adds visibility into existing task state.

</domain>

<decisions>
## Implementation Decisions

### Badge appearance
- Plain number next to the icon — no colored circle, no background shape
- System regular font weight — blends with other menu bar items
- System adaptive color (system label color) — white in dark mode, black in light mode, fully native
- No accent color or custom styling

### Transition behavior
- Count appears and changes instantly — no fade, no animation, no bump effect
- Number swaps immediately when count changes (add, complete, delete)
- No transition delay between states

### Count semantics
- Count = unchecked tasks only. Completed (checked) tasks are invisible to the badge.
- Reactive updates — badge updates when user adds, checks, or deletes a task. No background polling.
- Badge updates from any task path — hotkey capture, panel interaction, any method of adding/completing
- Purely unchecked count — no ratio display, no "3/7" style

### Edge cases
- Always show exact number — no cap at 99+, show the real count even at high numbers
- Always on — no Settings toggle to hide the badge. It shows when tasks exist, hides at zero.

### Claude's Discretion
- Number positioning relative to icon (right of icon, or other natural placement)
- Disappear timing when count reaches zero (instant vs brief delay for confirmation feel)
- Status item width handling as digit count changes (dynamic vs fixed reservation)
- Badge display at app launch — whether to show immediately from persisted data or wait for load confirmation

</decisions>

<specifics>
## Specific Ideas

- Save `dateAdded` timestamp in the task data model, but do not display it anywhere in the UI. This is for future use, not for this phase's visible output.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-task-count-badge*
*Context gathered: 2026-02-18*
