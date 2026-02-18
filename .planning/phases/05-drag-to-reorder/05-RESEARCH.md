# Phase 5: Drag-to-Reorder - Research

**Researched:** 2026-02-18
**Domain:** SwiftUI List drag reordering on macOS — `onMove` + `moveDisabled` + `onHover` pattern
**Confidence:** MEDIUM — API shape is HIGH confidence from official docs; runtime interaction behavior on macOS is MEDIUM (community-verified, hardware validation still required per STATE.md blocker)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REOR-01 | User can drag tasks to reorder via drag handle | `onMove(perform:)` on ForEach inside List enables drag reorder; `moveDisabled(!isHovering)` on the row restricts initiation to the handle only |
| REOR-02 | Task order persists across app restarts | `onMove` closure calls `tasks.move(fromOffsets:toOffset:)` then `persist()` — identical pattern to existing add/toggle/delete; no model changes needed |
| REOR-03 | Drag handle visible on each task row (not full-row drag) | SF Symbol `"line.3.horizontal"` in HStack; `onHover` on the handle drives `isHovering` state that gates `moveDisabled` |
</phase_requirements>

---

## Summary

SwiftUI provides a native drag-reorder mechanism for `List` via the `onMove(perform:)` modifier applied to a `ForEach` inside the list. On macOS the drag handle appears automatically when the list row is in a movable state. The critical pattern for this phase — locked in STATE.md — is `moveDisabled(!isHovering)` combined with `onHover` on a visible drag handle icon. This confines drag initiation to the handle area, preventing gesture conflicts with the checkbox toggle and any future interactive elements.

Order persistence requires zero model changes: the `onMove` closure calls `tasks.move(fromOffsets:toOffset:)` (a Swift stdlib method), which mutates the in-memory `[Task]` array in place. The existing `persist()` call in TaskStore then writes the reordered array to JSON atomically — the persisted order is the array index order, which is already what FileStore serializes and deserializes.

The MEDIUM confidence rating on the `onMove` + `onHover` interaction reflects that the behavior has been documented by community sources (nilcoalescing.com) and confirmed by multiple corroborating searches, but it has not been validated on actual macOS hardware in this project's dev environment (Linux). The STATE.md blocker explicitly flags this for hardware validation before the phase is declared complete.

**Primary recommendation:** Use `ForEach(store.tasks) { task in ... }.onMove { ... }` inside the existing `List`, with per-row `@State var isHovering = false` gating `.moveDisabled(!isHovering)`, and an `Image(systemName: "line.3.horizontal").onHover { isHovering = $0 }` as the visible handle. Call `persist()` inside the `onMove` closure after the array mutation.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `List` + `ForEach` | macOS 10.15+ | Renders task rows with native drag reorder support | Built-in; `onMove` is the Apple-endorsed reorder mechanism |
| `onMove(perform:)` | macOS 10.15+ | Activates drag-reorder interaction on ForEach rows | The only SwiftUI-native API for List row reordering |
| `moveDisabled(_:)` | macOS 10.15+ | Conditionally disables drag on a per-row basis | Needed to restrict drag initiation to handle only |
| `onHover(perform:)` | macOS 10.15+ | Detects pointer entry/exit on the drag handle | Drives the `isHovering` boolean that gates `moveDisabled` |
| `Array.move(fromOffsets:toOffset:)` | Swift stdlib | Reorders the in-memory array to match user drag | Directly matches the `onMove` closure signature |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SF Symbol `"line.3.horizontal"` | macOS 11+ | Standard drag handle icon | Use as the grab target; renders the three-bar "hamburger" handle |
| `NSCursor.openHand` / `.closedHand` | AppKit | Cursor feedback on drag handle hover | Optional polish; can set via `onHover` if desired |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `onMove` + `moveDisabled` + `onHover` | `draggable(_:)` + `dropDestination(for:)` | Full custom drag/drop is significantly more complex; `onMove` is the right API for single-list reordering |
| `onMove` + `moveDisabled` + `onHover` | Full-row drag (no handle, `onMove` always enabled) | Full-row drag conflicts with checkbox gesture and future text fields — explicitly out of scope per REQUIREMENTS.md |
| `ForEach` with `onMove` | `ForEach($tasks, editActions: [.move])` | `editActions:` binding initializer (macOS 13+) bypasses `onMove` callback, making it hard to call `persist()` after mutation |

**Installation:** No new packages. All APIs are part of SwiftUI / Swift stdlib.

---

## Architecture Patterns

### Recommended Change Surface

```
QuickTask/Sources/
├── Store/
│   └── TaskStore.swift      # Add move(_:) mutation method
└── Views/
    ├── TaskListView.swift    # ForEach + .onMove wired to store.move
    └── TaskRowView.swift     # Add drag handle icon + isHovering state + .moveDisabled
```

No new files required. Changes are confined to existing files.

### Pattern 1: ForEach + onMove (the activation layer)

**What:** Apply `onMove` to the `ForEach` inside the `List`, not to the `List` itself. The `onMove` closure receives source `IndexSet` and destination `Int`, passes them to the store, then persists.

**When to use:** Always — this is the only way to enable SwiftUI List row reordering with a custom callback.

**Example:**
```swift
// Source: https://developer.apple.com/documentation/SwiftUI/Making-a-view-into-a-drag-source
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
```

### Pattern 2: moveDisabled + onHover (the handle gate)

**What:** Each row tracks its own `isHovering` boolean via `@State`. The drag handle image has `onHover` to set that boolean. `.moveDisabled(!isHovering)` is applied to the HStack so only hovering over the handle activates dragging.

**Critical behavior (MEDIUM confidence — community-sourced, hardware validate):** During an active drag operation, SwiftUI does not update `onHover` callbacks. This means once a drag starts, `isHovering` stays `true` for the duration of the drag even if the pointer moves off the handle. The drag completes normally.

**When to use:** Required per STATE.md decision — must be built this way from first line, not retrofitted.

**Example:**
```swift
// Source: nilcoalescing.com (community verified, macOS-specific)
// Applied inside TaskRowView
@State private var isHovering = false

var body: some View {
    HStack {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary)
            .onHover { hovering in
                isHovering = hovering
            }

        Toggle(isOn: ...) { Text(task.title) }
            .toggleStyle(.checkbox)

        Spacer()

        Button { store.delete(task) } label: {
            Image(systemName: "trash").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
    .opacity(task.isCompleted ? 0.4 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
    .moveDisabled(!isHovering)
}
```

### Pattern 3: TaskStore.move mutation

**What:** Add a `move(fromOffsets:toOffset:)` method to TaskStore that applies the Swift stdlib array mutation and calls `persist()`. Mirrors the existing `add`, `toggle`, `delete` pattern.

**When to use:** Called exclusively from the `onMove` closure in TaskListView.

**Example:**
```swift
// Consistent with existing TaskStore mutation pattern
func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    tasks.move(fromOffsets: source, toOffset: destination)
    persist()
}
```

**Persistence notes:** The `[Task]` array is serialized by index order. After `tasks.move(fromOffsets:toOffset:)`, the array is reordered in memory. The next `persist()` call writes that reordered array to JSON. On next launch, `loadAll()` decodes the array in the saved order. No sortOrder field, no schema migration, no changes to the `Task` struct required.

### Anti-Patterns to Avoid

- **Applying onMove to List directly (not ForEach):** The `onMove` modifier is on `DynamicViewContent`, which `ForEach` conforms to. Attaching it to `List` is a compiler error on macOS.
- **Sharing a single isHovering across all rows:** If `isHovering` lives in the parent view (TaskListView), hovering one row's handle can incorrectly enable drag on all rows. Keep `@State var isHovering` inside `TaskRowView`.
- **Using ForEach(0..<tasks.count):** Integer-range ForEach can cause index-out-of-range crashes when the array mutates concurrently. Use `ForEach(store.tasks)` with the Identifiable conformance (already present via `Task: Identifiable`).
- **Using ForEach($tasks, editActions: [.move]):** This binding-based form auto-mutates the array without calling `persist()`. Sidestep it entirely; use `onMove` with explicit `store.move()` to keep persistence in the store.
- **Adding .onTapGesture to rows with onMove active:** A known macOS bug (FB7367473) causes `onTapGesture(count:)` on a row to remove the drag blue-line indicator and break `onMove`. Avoid tap gesture modifiers on the row HStack; the existing checkbox Toggle is fine (it uses its own recognizer, not `onTapGesture`).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drag reorder of List rows | Custom `DragGesture` + geometry tracking | `ForEach.onMove` | `onMove` handles all hit-testing, drop target rendering (blue line), multi-item selection, accessibility |
| Order persistence | sortOrder Int field on Task model | Array index order already persisted via existing JSON encode/decode | Adding a sortOrder field requires migration logic and adds write amplification; array position is free |
| Drag handle hit area | Invisible overlay GestureView | `Image.onHover` toggling `moveDisabled` | The `onHover` approach is simpler and the correct macOS idiom for pointer-based interaction |
| Cross-list drop prevention | Custom UTType registration | Only one List in this app — not needed | The crash scenario (cross-list drop with no onInsert) only applies when multiple Lists with onMove exist in the same view |

**Key insight:** `onMove` is purpose-built for single-list reordering. The only complexity here is the handle-gating pattern (`moveDisabled` + `onHover`), which is a well-documented, ~10-line addition to TaskRowView.

---

## Common Pitfalls

### Pitfall 1: isHovering Scoped at Parent Level

**What goes wrong:** A shared `@State var isHovering` in TaskListView means any row becomes draggable when you hover any other row's handle. Rows can be accidentally grabbed via mouse movement with no handle interaction.

**Why it happens:** If `isHovering` is in the parent, `moveDisabled(!isHovering)` applies the same boolean to every row.

**How to avoid:** Declare `@State private var isHovering = false` inside `TaskRowView`. Each row instance gets its own isolated state.

**Warning signs:** During testing, notice that mousing over handle on row 1 enables dragging on row 2 or 3.

### Pitfall 2: ForEach with Integer Range (Stale Index Crash)

**What goes wrong:** Using `ForEach(0..<store.tasks.count)` with index-based subscript causes "Fatal error: Index out of range" when a drag completes and the array is mutated.

**Why it happens:** The integer range is evaluated once. After `move(fromOffsets:toOffset:)` mutates the array, some row views try to subscript the old index against a now-reordered array.

**How to avoid:** Use `ForEach(store.tasks)` with Identifiable items (already the case — `Task: Identifiable` with UUID id).

**Warning signs:** App crashes on drag completion, not during the drag itself.

### Pitfall 3: onMove Does Not Fire on macOS Without Correct ForEach Placement

**What goes wrong:** The drag handle appears (or drag seems to work) but the `onMove` closure never fires, so the array is never reordered.

**Why it happens:** On macOS, `onMove` must be on the `ForEach`, not the `List`. Placing it on `List` is a compiler error; placing it on an inner `VStack` or `Group` silently does nothing.

**How to avoid:** `ForEach(...).onMove { ... }` — the modifier chain is on the ForEach value.

**Warning signs:** Drag animation works but task order resets to original after drop.

### Pitfall 4: Persistence Not Called After Move

**What goes wrong:** Tasks reorder in the UI for the current session but revert to original order on app relaunch.

**Why it happens:** The `onMove` closure calls `tasks.move(fromOffsets:toOffset:)` but forgets to call `persist()`. The @Observable property change is in-memory only.

**How to avoid:** The `move(fromOffsets:toOffset:)` method in TaskStore always calls `persist()` as its last line, matching the established pattern.

**Warning signs:** Reorder works in-session but not across app restarts (REOR-02 failure).

### Pitfall 5: editActions Binding Form Bypasses persist()

**What goes wrong:** Using `ForEach($store.tasks, editActions: [.move])` mutates the array automatically but never calls `persist()`.

**Why it happens:** The `editActions:` form handles the mutation internally. There is no callback hook like `onMove`.

**How to avoid:** Use the non-binding `ForEach(store.tasks)` with explicit `onMove` closure that calls `store.move(...)`.

**Warning signs:** Same as Pitfall 4 — reorder works in session but not across restarts.

---

## Code Examples

Verified patterns from official sources and community documentation:

### Complete TaskListView with onMove

```swift
// Source: https://developer.apple.com/documentation/SwiftUI/Making-a-view-into-a-drag-source (official)
// + store.move call (project-specific pattern, consistent with existing mutations)
struct TaskListView: View {
    @Environment(TaskStore.self) private var store

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
    }
}
```

### TaskRowView with drag handle + moveDisabled

```swift
// Source: nilcoalescing.com pattern (community, MEDIUM confidence — hardware validate)
// moveDisabled API: https://developer.apple.com/documentation/SwiftUI/documentation/swiftui/view/movedisabled%28_%3A%29 (HIGH)
// onHover API: https://developer.apple.com/documentation/SwiftUI/documentation/swiftui/view/onhover%28perform%3A%29 (HIGH)
struct TaskRowView: View {
    @Environment(TaskStore.self) private var store
    @State private var isHovering = false

    let task: Task

    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .onHover { hovering in
                    isHovering = hovering
                }

            Toggle(
                isOn: Binding(
                    get: { task.isCompleted },
                    set: { _ in store.toggle(task) }
                )
            ) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
            }
            .toggleStyle(.checkbox)

            Spacer()

            Button {
                store.delete(task)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete task")
        }
        .opacity(task.isCompleted ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
        .moveDisabled(!isHovering)
    }
}
```

### TaskStore.move mutation

```swift
// Source: Array.move(fromOffsets:toOffset:) — Swift stdlib (HIGH confidence)
// Pattern: consistent with existing add/toggle/delete mutations in TaskStore
func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    tasks.move(fromOffsets: source, toOffset: destination)
    persist()
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `EditButton` required to enter edit mode for drag | `onMove` with `moveDisabled` works without `EditButton` on macOS | macOS 10.15+ (always true for this platform) | No toolbar Edit button needed; drag is always potentially available |
| `onDrag` / `onDrop` for list reordering | `onMove` for same-list reorder; `draggable`/`dropDestination` for cross-app | Pre-macOS 13 vs. macOS 13+ | `onMove` is simpler and sufficient for same-list reorder; don't use `draggable` for this use case |
| `ForEach($data, editActions: [.move])` | `ForEach(data).onMove { }` | macOS 13+ introduced binding form | Binding form is convenient but bypasses custom callbacks; use `onMove` form when `persist()` must be called |

**Deprecated/outdated:**
- EditButton-gated drag: Not required on macOS. `onMove` is active regardless of edit mode state on macOS (unlike iOS where edit mode is typically required). The `editMode` environment key is iOS-centric; macOS ignores it for List drag behavior.

---

## Open Questions

1. **Does `onMove` on macOS work without `.environment(\.editMode, .constant(.active))`?**
   - What we know: Multiple community sources confirm macOS List `onMove` fires without `EditButton` or forced `editMode`. Official docs don't explicitly address macOS edit mode requirements.
   - What's unclear: Whether there are any edge cases (specific macOS versions) where this does not hold.
   - Recommendation: Test on first run. If drag doesn't initiate, add `.environment(\.editMode, .constant(.active))` to the List as a fallback. This is a one-line fix if needed.

2. **Does the drag blue-line indicator render correctly with the moveDisabled + onHover pattern?**
   - What we know: The indicator is part of SwiftUI's List drag machinery and should appear on eligible rows.
   - What's unclear: Whether `moveDisabled(true)` on a row suppresses the indicator only while disabled (expected) or permanently (would be a bug).
   - Recommendation: Validate on hardware. If the indicator doesn't appear, this is a known macOS SwiftUI edge case requiring investigation.

3. **Does `onHover` inside a List row behave reliably on macOS?**
   - What we know: `onHover` is documented for macOS 10.15+ and the pattern is described as working by nilcoalescing.com with explicit notes about drag-phase behavior.
   - What's unclear: Whether there are List-specific quirks where hover tracking is unreliable (e.g., fast mouse movement, scroll during hover).
   - Recommendation: This is the STATE.md blocker — "validate on real hardware before declaring complete." Accept MEDIUM confidence and mark in verification checklist.

---

## Sources

### Primary (HIGH confidence)

- `/websites/developer_apple_swiftui` (Context7) — `onMove`, `moveDisabled`, `onHover`, `ForEach editActions`, `draggable/dropDestination` API shapes
- https://developer.apple.com/documentation/SwiftUI/Making-a-view-into-a-drag-source — official `onMove` + `moveDisabled` usage, ForEach requirement
- https://developer.apple.com/documentation/SwiftUI/documentation/swiftui/view/movedisabled%28_%3A%29 — `moveDisabled` signature and availability (macOS 10.15+)
- https://developer.apple.com/documentation/SwiftUI/documentation/swiftui/view/onhover%28perform%3A%29 — `onHover` signature and availability (macOS 10.15+)
- Swift stdlib `Array.move(fromOffsets:toOffset:)` — matches `onMove` closure signature exactly

### Secondary (MEDIUM confidence)

- https://nilcoalescing.com/blog/ListReorderingWhileStillBeingAbleToEditTheListItems/ — complete `moveDisabled` + `onHover` + drag handle pattern for macOS, including the critical "onHover not updated during active drag" behavior note. Multiple corroborating searches confirmed this pattern.
- https://swiftdevjournal.com/moving-list-items-using-drag-and-drop-in-swiftui-mac-apps/ — confirms ForEach requirement for `onMove` on macOS; binding form distinction

### Tertiary (LOW confidence)

- https://github.com/feedback-assistant/reports/issues/46 — `onTapGesture(count:2)` breaks `onMove` blue-line indicator on macOS (FB7367473). Old report (macOS 10.15 era), may be fixed. The current codebase doesn't use double-tap gestures so this pitfall may not apply, but worth noting.
- General WebSearch results on onMove + EditMode — consistent with above but not individually verified against official docs.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs verified against official SwiftUI documentation via Context7
- Architecture: HIGH — ForEach + onMove pattern is from official docs; TaskStore mutation pattern is from existing codebase
- `moveDisabled` + `onHover` interaction at runtime: MEDIUM — API shape is HIGH; runtime behavior (drag phase, hover update suppression) is community-sourced only
- Pitfalls: MEDIUM — most are from direct API reasoning or well-documented community reports; hardware not available for pre-validation

**Research date:** 2026-02-18
**Valid until:** 2026-08-18 (SwiftUI APIs are stable; community patterns are mature)

**Hardware validation required:** Yes — STATE.md blocker: `onMove` + `onHover` drag handle interaction must be validated on real macOS hardware before phase declared complete.
