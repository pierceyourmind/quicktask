# Phase 7: Bulk-Clear Completed - Research

**Researched:** 2026-02-18
**Domain:** SwiftUI `confirmationDialog` + `TaskStore` mutation — macOS floating panel footer button
**Confidence:** HIGH — all core APIs verified via Context7 official docs; macOS-specific dialog behavior verified via authoritative community sources

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CLEAR-01 | User can bulk-clear all completed tasks | `tasks.removeAll(where: { $0.isCompleted })` in a new `clearCompleted()` mutation on TaskStore; single `persist()` call after; wired to a footer button in TaskListView |
| CLEAR-02 | Confirmation dialog shown before clearing | `.confirmationDialog(_:isPresented:actions:message:)` with a `.destructive` role button; driven by `@State private var showConfirmation = false`; available macOS 12.0+; project targets macOS 14 so availability is satisfied |
| CLEAR-03 | "Clear" button only visible when completed tasks exist | Button rendered conditionally: `if store.completedCount > 0 { ... }` — absent entirely (not disabled) when count is zero; driven reactively by the `@Observable` TaskStore |
</phase_requirements>

---

## Summary

Phase 7 adds bulk-clear of completed tasks in three parts: a new `clearCompleted()` mutation on `TaskStore`, a conditional footer button in `TaskListView`, and a `confirmationDialog` confirmation step. All three are narrow, low-risk changes to existing files with no new dependencies.

The locked decision from STATE.md is: `confirmationDialog` (not `.alert`), and a single `removeAll(where:)` + single `persist()` call. `confirmationDialog` is the correct API — it is the modern macOS-native replacement for the deprecated `actionSheet`, renders as a modal alert dialog on macOS 12+, and automatically includes a Cancel button. The project targets macOS 14, so availability is not a concern.

The "absent when no completed tasks" requirement (CLEAR-03) means the button is conditionally rendered via an `if` expression in the View body, not rendered as a disabled control. This is a behavioral distincton: a disabled button still occupies space and communicates affordance; a conditionally absent button communicates that there is nothing to clear. The `@Observable` macro on TaskStore means the view automatically re-evaluates when `tasks` changes, so the button appears and disappears without extra plumbing.

**Primary recommendation:** Add `clearCompleted()` to TaskStore (mirrors existing `delete`/`toggle` mutation pattern), add a `safeAreaInset(edge: .bottom)` footer to TaskListView containing the conditional button with `.confirmationDialog` attached, and add a `completedCount` computed property to TaskStore to drive both the button label ("Clear N completed") and the visibility condition.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `confirmationDialog(_:isPresented:actions:message:)` | macOS 12.0+ | Presents a destructive confirmation before clearing | Official Apple API; replaces deprecated `actionSheet`; renders as native modal alert on macOS |
| `Array.removeAll(where:)` | Swift stdlib | Removes all elements matching a predicate in one pass | Single in-place mutation; O(n); no new dependencies |
| SwiftUI `safeAreaInset(edge:alignment:spacing:content:)` | macOS 12.0+ | Adds a footer area below the List without shrinking list content | The correct way to add persistent footer content to a scrollable list without clipping rows |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@State private var showConfirmation = false` | SwiftUI | Drives dialog presentation | Required by `.confirmationDialog(isPresented:)` binding |
| `@Observable` TaskStore computed property `completedCount` | Swift 5.9+ | Drives button label count and conditional rendering | Avoids duplicating `filter` logic in the view |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `confirmationDialog` | `.alert` | `.alert` is for informational/error messages; `confirmationDialog` is for action confirmation — semantically correct and the locked decision |
| `safeAreaInset(edge: .bottom)` footer | `VStack` wrapping List + footer | `VStack` approach shrinks the List height, cutting off rows; `safeAreaInset` keeps List at full height and overlays/insets the bottom edge |
| Conditional `if` (button absent) | `Button(...).disabled(true)` | Per CLEAR-03: button must be ABSENT when no completed tasks exist, not disabled; `if store.completedCount > 0 { }` achieves this |
| `removeAll(where:)` once | Loop calling `delete(_:)` | Multiple calls each call `persist()` individually; single `removeAll` + single `persist()` is the locked decision and is simpler |

**Installation:** No new packages. All APIs are part of SwiftUI and Swift stdlib.

---

## Architecture Patterns

### Recommended Change Surface

```
QuickTask/Sources/
├── Store/
│   └── TaskStore.swift       # Add completedCount computed property + clearCompleted() mutation
└── Views/
    └── TaskListView.swift    # Add safeAreaInset footer with conditional button + confirmationDialog
```

No new files required. Two existing files modified. No changes to Task model, ContentView, TaskRepository, or FileStore.

### Pattern 1: TaskStore mutation — clearCompleted()

**What:** Follows the established mutation pattern: mutate `tasks` in-memory, then call `persist()`. Single `removeAll(where:)` replaces all completed tasks at once; a single `persist()` writes the result.

**When to use:** Triggered exclusively from the confirmation dialog's destructive action button.

**Example:**
```swift
// Source: consistent with existing add/toggle/delete/move mutation pattern in TaskStore
// Array.removeAll(where:) — Swift stdlib

/// The count of tasks that have been completed.
/// Used to drive the "Clear N completed" button label and visibility.
var completedCount: Int {
    tasks.filter { $0.isCompleted }.count
}

/// Removes all completed tasks in a single batch operation.
/// Called only after user confirms the confirmation dialog.
func clearCompleted() {
    tasks.removeAll(where: { $0.isCompleted })
    persist()
}
```

**Design note:** `completedCount` as a computed property on TaskStore (alongside the existing `incompleteCount`) keeps filter logic out of views and is automatically tracked by the `@Observable` macro — views reading `completedCount` re-render when `tasks` changes.

### Pattern 2: confirmationDialog — the locked API

**What:** `.confirmationDialog(_:isPresented:actions:message:)` presents a macOS-native modal alert dialog. On macOS it shows the dialog title, a Cancel button (added automatically), and the action buttons defined in the `actions` closure. The destructive action button gets a red label by default.

**Availability:** macOS 12.0+. Project targets macOS 14 — no availability guard needed.

**Example:**
```swift
// Source: https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:message:)-2s7pz
// (official Apple docs, HIGH confidence)

@State private var showConfirmation = false

Button("Clear \(store.completedCount) completed") {
    showConfirmation = true
}
.confirmationDialog(
    "Clear completed tasks?",
    isPresented: $showConfirmation
) {
    Button("Clear \(store.completedCount) completed", role: .destructive) {
        store.clearCompleted()
    }
} message: {
    Text("This will permanently remove all completed tasks.")
}
```

**macOS-specific behavior (verified):** On macOS, `confirmationDialog` renders as a centered modal alert dialog — not a bottom sheet (iOS) or popover (iPad). macOS automatically adds a Cancel button. The destructive button renders in red. The app icon is shown by default. This is the correct and expected native macOS behavior.

### Pattern 3: Conditional footer button — safeAreaInset

**What:** `safeAreaInset(edge: .bottom)` on the `List` in TaskListView injects a footer view below the list content. The footer is only added when `store.completedCount > 0` via a conditional `if` block.

**Why `safeAreaInset` over VStack:** Wrapping the List in a VStack with a footer below it would reduce the List's visible frame height. `safeAreaInset` keeps the List at full height and adjusts the scroll content inset so rows don't scroll behind the footer — standard pattern for persistent bottom-of-list controls.

**Example:**
```swift
// Source: https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)-6gwby
// (official Apple docs, HIGH confidence)

List {
    ForEach(store.tasks) { task in
        TaskRowView(task: task)
            .listRowSeparator(.hidden)
    }
    .onMove { indices, newOffset in
        store.move(fromOffsets: indices, toOffset: newOffset)
    }
}
.listStyle(.plain)
.safeAreaInset(edge: .bottom) {
    if store.completedCount > 0 {
        HStack {
            Spacer()
            Button("Clear \(store.completedCount) completed") {
                showConfirmation = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal)
            Spacer()
        }
        .background(.regularMaterial)
        .confirmationDialog(
            "Clear completed tasks?",
            isPresented: $showConfirmation
        ) {
            Button("Clear \(store.completedCount) completed", role: .destructive) {
                store.clearCompleted()
            }
        } message: {
            Text("This will permanently remove all completed tasks.")
        }
    }
}
```

**Alternative footer placement:** `.confirmationDialog` can be placed on any ancestor view — it does not need to be on the trigger button itself. Placing it on the List or the VStack in ContentView is equally valid if attaching to the conditional view proves awkward. The `isPresented` binding drives presentation regardless of where the modifier is in the tree.

### Anti-Patterns to Avoid

- **Calling `delete(_:)` in a loop instead of `removeAll(where:)`:** Each `delete` call invokes `persist()`. For N completed tasks, that is N disk writes. The locked decision is one `removeAll` + one `persist()`.
- **Using `.disabled(true)` instead of conditional rendering:** CLEAR-03 requires the button be ABSENT, not disabled. A disabled button is a visible affordance communicating "this will be available later." No completed tasks means there is nothing to clear — the button should not exist.
- **Using `.alert` instead of `confirmationDialog`:** `.alert` is for informational messages and errors. `.confirmationDialog` is the correct API for action confirmation and is the locked decision. On macOS, both render as modal dialogs, but the semantics differ and Apple's HIG prefers `confirmationDialog` for user-confirmation flows.
- **Placing `@State var showConfirmation` outside TaskListView:** `@State` is view-local. It must live in the view that owns the button and the dialog. Do not lift it to TaskStore (TaskStore is for data, not UI state) or ContentView (unnecessary coupling).
- **Wrapping List in VStack with a bottom bar:** This reduces the List's displayed height. Use `safeAreaInset` instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Confirmation before destructive action | Custom confirmation state + custom dialog view | `.confirmationDialog` | Platform-native dialog, auto Cancel button, destructive button styling, accessibility |
| Remove all items matching predicate | `for` loop with `tasks.remove(at:)` | `Array.removeAll(where:)` | Single-pass, stdlib, safe with mutation during iteration |
| Footer below scrollable list | VStack wrapping List + a bottom HStack | `List.safeAreaInset(edge: .bottom)` | Preserves full List height; insets scroll content so last row is reachable above footer |

**Key insight:** The entire phase is three focused additions to two existing files, all using stdlib or framework APIs. There is nothing to invent.

---

## Common Pitfalls

### Pitfall 1: Button Absent vs. Disabled Confusion

**What goes wrong:** Developer renders the button as `.disabled(store.completedCount == 0)` instead of conditionally absent. Button persists in the footer at all times, just greyed out.

**Why it happens:** Disabling is the most common default for "not yet applicable" UI; conditional removal requires explicit `if` guard.

**How to avoid:** `if store.completedCount > 0 { Button(...) }` inside the `safeAreaInset` closure. No button in DOM when count is zero. CLEAR-03 states "absent when no completed tasks exist — it does not appear as a disabled control."

**Warning signs:** Footer shows a greyed-out "Clear 0 completed" button when all tasks are unchecked.

### Pitfall 2: Multiple persist() Calls from Loop Deletion

**What goes wrong:** `store.tasks.filter { $0.isCompleted }.forEach { store.delete($0) }` calls `persist()` once per deleted task.

**Why it happens:** Reaching for the existing `delete(_:)` method seems intuitive, but it was designed for single-item deletion.

**How to avoid:** `clearCompleted()` uses `tasks.removeAll(where: { $0.isCompleted })` then one `persist()`. This is the locked decision in STATE.md.

**Warning signs:** For 10 completed tasks, FileStore is called 10 times. Performance impact is negligible for small task lists but is architecturally wrong.

### Pitfall 3: confirmationDialog Not Appearing in NSPanel Context

**What goes wrong:** Dialog is triggered (`showConfirmation = true`) but never visually appears, or appears behind the panel.

**Why it happens:** `confirmationDialog` on macOS presents a modal sheet attached to the key window. Because `FloatingPanel` is a `.nonactivatingPanel`, it does not activate the app. If the panel does not hold key-window status at the moment the dialog is triggered, the dialog may not present correctly.

**How to avoid:** This is a MEDIUM-confidence concern that must be validated on macOS hardware. The panel does return `canBecomeKey = true` and does become key when shown, so in practice the dialog should present normally. If it does not, the fallback is to use `NSAlert` called programmatically from within the button action (AppKit approach, bypasses SwiftUI dialog machinery entirely). Flag this for hardware validation in the PLAN's verification checklist.

**Warning signs:** Tapping the "Clear N completed" button sets `showConfirmation = true` but nothing appears on screen.

### Pitfall 4: State Variable Ownership — showConfirmation in Wrong Scope

**What goes wrong:** `showConfirmation` is lifted to ContentView or injected via environment, creating unnecessary coupling.

**Why it happens:** Unfamiliarity with where `@State` should live for dialog presentation.

**How to avoid:** `@State private var showConfirmation = false` belongs in TaskListView — the view that owns both the trigger button and the `.confirmationDialog` modifier. It is purely ephemeral UI state.

**Warning signs:** Other views can read or set `showConfirmation`, creating hidden state coupling.

### Pitfall 5: completedCount Reactivity

**What goes wrong:** `completedCount` is computed correctly but the view does not re-render when the count changes, leaving a stale "Clear 5 completed" label after tasks are cleared.

**Why it happens:** If `completedCount` is computed inside the View body directly rather than via a property on the `@Observable` TaskStore, the observation tracking may not connect properly.

**How to avoid:** Define `completedCount` as a computed property on `TaskStore` (alongside `incompleteCount`). The `@Observable` macro tracks reads of `tasks` inside this computed property, so any view reading `store.completedCount` will re-render when `tasks` changes. This is exactly how `incompleteCount` already works.

**Warning signs:** After `clearCompleted()` runs, the button label still shows the old count, or the button fails to disappear.

---

## Code Examples

Verified patterns from official sources:

### TaskStore additions

```swift
// Source: Swift stdlib Array.removeAll(where:) + existing TaskStore mutation pattern

/// The count of completed tasks.
/// Drives the "Clear N completed" button label and its conditional visibility.
/// The @Observable macro tracks reads of `tasks` here, so views reading this
/// property re-render whenever tasks changes.
var completedCount: Int {
    tasks.filter { $0.isCompleted }.count
}

/// Removes all completed tasks in a single batch and persists the result.
/// Single removeAll + single persist() — matches the locked STATE.md decision.
func clearCompleted() {
    tasks.removeAll(where: { $0.isCompleted })
    persist()
}
```

### TaskListView with footer + confirmationDialog

```swift
// Source:
// confirmationDialog: https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:message:)-2s7pz
// safeAreaInset: https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)-6gwby

struct TaskListView: View {

    @Environment(TaskStore.self) private var store
    @State private var showConfirmation = false

    var body: some View {
        List {
            ForEach(store.tasks) { task in
                TaskRowView(task: task)
                    .listRowSeparator(.hidden)
            }
            .onMove { indices, newOffset in
                store.move(fromOffsets: indices, toOffset: newOffset)
            }
        }
        .listStyle(.plain)
        .overlay {
            if store.tasks.isEmpty {
                ContentUnavailableView(
                    "All clear.",
                    systemImage: "checkmark.circle",
                    description: Text("Add a task to get started.")
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if store.completedCount > 0 {
                HStack {
                    Spacer()
                    Button("Clear \(store.completedCount) completed") {
                        showConfirmation = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    Spacer()
                }
                .background(.regularMaterial)
                .confirmationDialog(
                    "Clear completed tasks?",
                    isPresented: $showConfirmation
                ) {
                    Button("Clear \(store.completedCount) completed", role: .destructive) {
                        store.clearCompleted()
                    }
                } message: {
                    Text("This will permanently remove all completed tasks.")
                }
            }
        }
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `actionSheet` modifier | `confirmationDialog` | iOS 15 / macOS 12 (2021) | `actionSheet` deprecated; `confirmationDialog` is the current API |
| VStack + bottom HStack for list footer | `safeAreaInset(edge: .bottom)` | macOS 12 / iOS 15 | `safeAreaInset` preserves List height; VStack approach shrinks it |
| `ObservableObject` + `@Published` | `@Observable` macro | macOS 14 / Swift 5.9 (2023) | Project already uses `@Observable`; computed properties on TaskStore are automatically tracked |

**Deprecated/outdated:**
- `actionSheet`: Replaced by `confirmationDialog` as of macOS 12. Do not use.
- Manual `objectWillChange.send()`: Not needed with `@Observable`. The macro handles observation automatically.

---

## Open Questions

1. **Does `confirmationDialog` present correctly from a `.nonactivatingPanel`?**
   - What we know: `FloatingPanel` returns `canBecomeKey = true` and becomes key when shown. `confirmationDialog` on macOS presents a modal dialog attached to the key window. In theory this should work correctly.
   - What's unclear: Whether the `.nonactivatingPanel` style mask or the panel's non-standard window level interferes with SwiftUI's dialog presentation machinery. No official documentation or verified community source addresses this specific combination.
   - Recommendation: Mark as MEDIUM confidence. Validate on macOS hardware as part of the phase verification. Fallback if SwiftUI dialog does not appear: use `NSAlert` called programmatically inside the button action — `NSAlert.runModal()` is platform-level and unaffected by SwiftUI's presentation system.

2. **Should `completedCount` be a property on TaskStore or computed inline in the View?**
   - What we know: `incompleteCount` already exists on TaskStore as a computed property and is correctly observed. The same pattern will work for `completedCount`.
   - What's unclear: Nothing — follow the existing `incompleteCount` pattern.
   - Recommendation: Add `completedCount` to TaskStore alongside `incompleteCount`. Consistent, observable, keeps filter logic out of views.

3. **Footer layout: HStack with Spacers vs. a styled `.bordered` button?**
   - What we know: The project uses `.buttonStyle(.plain)` throughout (TaskRowView delete button). The `safeAreaInset` footer needs a background so it reads as a distinct footer area, not a floating button. `.regularMaterial` matches the ContentView background.
   - What's unclear: Exact padding and visual weight — this is Claude's discretion at planning time.
   - Recommendation: Keep it simple — centered text button with `.plain` style and `.secondary` foreground, `.regularMaterial` background on the footer container. Matches the existing visual language.

---

## Sources

### Primary (HIGH confidence)

- `/websites/developer_apple_swiftui` (Context7) — `confirmationDialog` API shape, signature, availability (macOS 12.0+), destructive button role, `safeAreaInset` API shape and availability
- https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:message:)-2s7pz — official `confirmationDialog` with message closure, destructive action pattern
- https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)-6gwby — official `safeAreaInset` signature and usage
- Swift stdlib `Array.removeAll(where:)` — single-pass predicate removal
- QuickTask codebase — existing `TaskStore` mutation pattern (`add`, `toggle`, `delete`, `move`); existing `incompleteCount` computed property as the model for `completedCount`

### Secondary (MEDIUM confidence)

- https://useyourloaf.com/blog/swiftui-confirmation-dialogs/ — confirmed macOS-specific `confirmationDialog` behavior: renders as centered modal alert, auto-adds Cancel button, destructive button in red, shows app icon by default
- https://serialcoder.dev/text-tutorials/swiftui/presenting-confirmation-dialogs-in-swiftui/ — confirmed `confirmationDialog` replaced deprecated `actionSheet`

### Tertiary (LOW confidence)

- General WebSearch results on `confirmationDialog` + `NSPanel` interaction — no specific verified source found; flagged as open question for hardware validation.

---

## Metadata

**Confidence breakdown:**
- Standard stack (APIs): HIGH — all APIs verified via Context7 official Apple docs; availability (macOS 12+) satisfied by project's macOS 14 target
- Architecture (mutation pattern, computed property): HIGH — directly mirrors existing `incompleteCount` / `delete` / `move` patterns in the live codebase
- `safeAreaInset` footer pattern: HIGH — official API, documented behavior
- `confirmationDialog` in NSPanel context: MEDIUM — API is HIGH confidence; interaction with `.nonactivatingPanel` is unverified; flagged for hardware validation
- Pitfalls: HIGH for logic pitfalls (loop delete, disabled vs. absent); MEDIUM for NSPanel dialog presentation

**Research date:** 2026-02-18
**Valid until:** 2026-08-18 (SwiftUI APIs are stable; `@Observable` and `confirmationDialog` are current-generation APIs)

**Hardware validation required:** Yes — `confirmationDialog` in `.nonactivatingPanel` context must be confirmed on real macOS hardware. If SwiftUI dialog does not appear, fallback to `NSAlert.runModal()`.
