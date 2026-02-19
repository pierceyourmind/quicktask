# QuickTask

## What This Is

A lightweight macOS menu bar app that lets you instantly capture, reorder, and manage tasks via a global keyboard shortcut. Built in Swift with a hybrid SwiftUI + AppKit architecture for users who lose mental tasks because the friction of opening a full todo app is too high.

## Core Value

Zero-friction task capture — the moment a task enters your mind, one hotkey and a few keystrokes saves it before it vanishes.

## Requirements

### Validated

- ✓ Global keyboard shortcut (Cmd+Shift+Space) summons floating panel — v1.0
- ✓ Quick text entry to add a task (type + Return) — v1.0
- ✓ Checklist with checkboxes to mark tasks complete — v1.0
- ✓ Completed tasks fade/dim but remain visible — v1.0
- ✓ Tasks persist to disk across app restarts and reboots — v1.0
- ✓ Menu bar icon for always-available access — v1.0
- ✓ Floating panel appears near center of screen (Spotlight-style) — v1.0
- ✓ Panel dismisses easily (Escape or click outside) — v1.0
- ✓ Task count badge on menu bar icon, hidden at zero — v1.1
- ✓ Drag-to-reorder tasks with drag handles, order persists — v1.1
- ✓ Configurable hotkey via recorder UI in Settings with reset-to-default — v1.1
- ✓ Bulk-clear completed tasks with confirmation dialog — v1.1

### Active

(None — planning next milestone)

### Out of Scope

- iCloud sync — local-only, single machine; destroys simplicity
- Accounts / authentication — personal local tool, no users
- Due dates / reminders — this is a capture tool, not a planner
- Categories / tags / projects — kills single-place simplicity
- Subtasks / nested tasks — checklist becomes project manager
- Mobile companion app — macOS only (deliberate constraint)
- Collaboration / sharing — personal tool
- Markdown in tasks — titles are one-line; rich formatting irrelevant
- Undo for bulk-clear — adds undo stack complexity disproportionate to the risk

## Context

Shipped v1.1 with 976 LOC Swift across 15 source files.
Tech stack: Swift 5.10 SPM, SwiftUI (macOS 14+), AppKit (NSPanel, NSStatusItem), KeyboardShortcuts 2.4.0+, Defaults 9.0.0.
Architecture: Hybrid SwiftUI + AppKit — SwiftUI for views, AppKit for NSPanel/NSStatusItem/global hotkey.
Persistence: JSON at ~/Library/Application Support/QuickTask/tasks.json via synchronous FileStore.
Patterns: withObservationTracking for AppKit-side reactive updates, safeAreaInset for footer overlays, moveDisabled/onHover for handle-gated drag.
Phase 7 (bulk-clear) verified on macOS hardware via UAT — 4/4 tests passed.

## Constraints

- **Platform**: macOS only — native Swift/SwiftUI + AppKit hybrid
- **Scope**: Deliberately minimal — resist feature creep
- **Performance**: Panel must appear instantly on hotkey press (< 200ms perceived)
- **Storage**: Local file-based persistence (no database server)
- **Target**: macOS 14+ (Sonoma) — required for @Observable and ContentUnavailableView

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Hybrid SwiftUI + AppKit (not pure SwiftUI) | MenuBarExtra(.window) cannot be programmatically toggled from hotkey | ✓ Good — NSPanel gives full control |
| KeyboardShortcuts SPM for global hotkey | SwiftUI .keyboardShortcut() doesn't fire when backgrounded | ✓ Good — works from any app |
| JSON + FileManager persistence | Simpler than Core Data for flat task list, no schema migrations | ✓ Good — synchronous writes fine for <500 tasks |
| Menu bar app with .accessory policy | Stays out of the way, always accessible, no Dock icon | ✓ Good |
| @Observable (macOS 14+) | No Combine needed, cleaner reactivity | ✓ Good — simpler than ObservableObject |
| NSPanel .nonactivatingPanel + canBecomeKey | Text input without stealing focus from other apps | ✓ Good — solves focus/input dual requirement |
| NotificationCenter bridge for Settings | @Environment(\.openSettings) unavailable in AppKit context | ✓ Good — clean workaround |
| SMAppService queried at runtime | User can change launch-at-login in System Settings independently | ✓ Good — no stale state |
| swift-tools-version 5.10 over 6.0 | Avoids strict concurrency errors before MainActor annotations | ✓ Good — pragmatic choice |
| variableLength NSStatusItem + button.title for badge | Dynamic width for digit count; no image compositing needed | ✓ Good — simplest approach |
| withObservationTracking one-shot loop for AppKit | Bridges @Observable to non-SwiftUI context without Combine | ✓ Good — clean reactive pattern |
| onMove on ForEach (not List) for drag reorder | Only DynamicViewContent has onMove; List silently ignores it | ✓ Good — correct API surface |
| moveDisabled + onHover for handle-gated drag | Prevents accidental reorders from checkbox/delete interactions | ✓ Good — clean gesture separation |
| Array index as persisted order (no sortOrder field) | JSON array serialization preserves order naturally | ✓ Good — zero schema change |
| KeyboardShortcuts 2.4.0+ for SwiftUI Recorder | v1.x had no SwiftUI recorder view; v2.x adds it natively | ✓ Good — drop-in control |
| KeyboardShortcuts.reset() not setShortcut(nil) | reset restores default shortcut; nil removes it entirely | ✓ Good — correct semantics |
| confirmationDialog not .alert for destructive action | confirmationDialog is the SwiftUI-native pattern for destructive confirms | ✓ Good |
| safeAreaInset(edge: .bottom) not VStack wrapper | Preserves full List scrollable height; footer floats over content | ✓ Good |
| confirmationDialog on List not conditional button | SwiftUI removes modifiers when parent view disappears | ✓ Good — dialog always available |

---
*Last updated: 2026-02-18 after v1.1 milestone shipped*
