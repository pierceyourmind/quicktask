# QuickTask

## What This Is

A lightweight macOS menu bar app that lets you instantly capture and check off tasks via a global keyboard shortcut. Built in Swift for users who lose mental tasks because the friction of opening a full todo app is too high.

## Core Value

Zero-friction task capture — the moment a task enters your mind, one hotkey and a few keystrokes saves it before it vanishes.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Global keyboard shortcut summons a small floating panel
- [ ] Quick text entry to add a task (type + Enter)
- [ ] Checklist with checkboxes to mark tasks complete
- [ ] Completed tasks fade/dim but remain visible
- [ ] Tasks persist to disk across app restarts and reboots
- [ ] Menu bar icon for always-available access
- [ ] Floating panel appears near center of screen (Spotlight-style)
- [ ] Panel dismisses easily (Escape or click outside)

### Out of Scope

- iCloud sync — local-only, single machine
- Accounts / authentication — no users, no login
- Due dates / reminders — this is a capture tool, not a planner
- Categories / tags / projects — keep it flat and simple
- Mobile companion app — macOS only
- Collaboration / sharing — personal tool

## Context

- Target: macOS (SwiftUI, native feel)
- The user's core frustration is "mental notes vanish" — the app must be faster to use than thinking "I'll remember that"
- Spotlight-style floating panel is the mental model for the UI
- Completed tasks should be visually distinct (faded/dimmed) but not deleted, so the user can see what they accomplished
- Local persistence only — no server, no network calls

## Constraints

- **Platform**: macOS only — native Swift/SwiftUI
- **Scope**: Deliberately minimal — resist feature creep
- **Performance**: Panel must appear instantly on hotkey press (< 200ms perceived)
- **Storage**: Local file-based persistence (no database server)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI over AppKit | Modern, less boilerplate, sufficient for this UI | — Pending |
| Global hotkey for primary access | Solves the core "too much friction" problem | — Pending |
| Local file persistence over CoreData | Simpler for a flat task list, no schema migrations | — Pending |
| Menu bar app (no dock icon) | Stays out of the way, always accessible | — Pending |

---
*Last updated: 2026-02-17 after initialization*
