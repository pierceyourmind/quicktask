# Milestones

## v1.0 MVP (Shipped: 2026-02-18)

**Phases completed:** 3 phases, 8 plans
**Swift LOC:** 843 across 15 source files
**Commits:** 54
**Timeline:** Feb 17-18, 2026 (2 days)

**Key accomplishments:**
- macOS menu bar agent with NSStatusItem, LSUIElement, .accessory activation policy
- Floating NSPanel with Spotlight-style positioning, .nonactivatingPanel for text input without focus steal
- Global Cmd+Shift+Space hotkey via KeyboardShortcuts, Escape/click-outside dismiss, focus-return
- @Observable TaskStore with JSON persistence to ~/Library/Application Support/QuickTask/
- Auto-focus capture UI, Return-to-add, native checkbox/strikethrough/delete task rows
- Right-click context menu, SMAppService launch-at-login, ContentUnavailableView empty state, smooth animations

---


## v1.1 Polish & Reorder (Shipped: 2026-02-18)

**Phases completed:** 4 phases, 4 plans, 8 tasks
**Swift LOC:** 976 across 15 source files (+133 from v1.0)
**Timeline:** Feb 17-18, 2026
**Git range:** `78d25fd..93abd2b`

**Key accomplishments:**
- Live task count badge on NSStatusItem via `withObservationTracking` reactive one-shot loop (Phase 4)
- Drag-to-reorder with per-row handle gating via `moveDisabled`/`onHover`, array-index-as-order persistence (Phase 5)
- Configurable hotkey recorder in Settings via KeyboardShortcuts v2.4.0 Recorder view with reset-to-default (Phase 6)
- Bulk-clear completed tasks with `confirmationDialog` footer via `safeAreaInset(edge: .bottom)` (Phase 7)

**UAT:** Phase 7 verified on macOS hardware — 4/4 tests passed.

---

