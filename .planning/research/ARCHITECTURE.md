# Architecture Research

**Domain:** macOS menu bar app — v1.1 feature integration (badge, drag-reorder, configurable hotkey, bulk-clear)
**Researched:** 2026-02-18
**Confidence:** HIGH (all four integration surfaces verified against live codebase; API patterns confirmed via official docs and library source)

---

## Scope

This document is **additive** to the existing `ARCHITECTURE.md` from v1.0 research. It answers: how do the four new v1.1 features integrate with the existing 843-LOC, 15-file hybrid SwiftUI + AppKit codebase, and what components must be added vs modified?

---

## Existing Architecture — Relevant Facts for v1.1

```
NSStatusItem (AppDelegate)
    button.image = NSImage(systemSymbolName: "checkmark.circle")
    button.action = handleStatusItemClick
    squareLength (fixed-width icon only)

PanelManager (singleton)
    configure(with: TaskStore)  ← store injected here, once
    show() / hide() / toggle()

FloatingPanel (NSPanel subclass)
    NSHostingView(rootView: ContentView().environment(store))

ContentView
    VStack { TaskInputView | Divider | TaskListView }
    fixed 400x300 frame

TaskListView
    List(store.tasks) { task in TaskRowView(task:) }
    .listStyle(.plain)

TaskStore (@Observable)
    var tasks: [Task]
    func add / toggle / delete

HotkeyService
    KeyboardShortcuts.onKeyUp(for: .togglePanel) { PanelManager.shared.toggle() }
    default: Ctrl+Option+Space

SettingsView (SwiftUI Form)
    Toggle "Launch at login"
    NSWindow managed by AppDelegate.openSettingsFromMenu()
```

---

## New Components Required

### New Files

| File | Type | Purpose |
|------|------|---------|
| `Sources/Views/TaskToolbarView.swift` | SwiftUI View | Bulk-clear toolbar row at bottom of panel; owns confirmationDialog state |

### Modified Files

| File | Change | Scope |
|------|--------|-------|
| `Sources/App/AppDelegate.swift` | Badge update logic | `setupStatusItem()` → variableLength; new `updateBadge(count:)` method; observes `TaskStore` |
| `Sources/Store/TaskStore.swift` | New mutation + computed property | `func clearCompleted()`, `var incompleteCount: Int` |
| `Sources/Views/TaskListView.swift` | ForEach + drag handle + toolbar | Wrap `List` body in `ForEach` with `.onMove`; add `TaskToolbarView` |
| `Sources/Views/TaskRowView.swift` | Drag handle affordance | Add `drag handle` icon region + `moveDisabled`/`onHover` pattern |
| `Sources/Settings/SettingsView.swift` | Hotkey recorder row | Add `KeyboardShortcuts.Recorder` row inside existing `Form` |
| `Sources/Hotkey/HotkeyService.swift` | No changes needed | `KeyboardShortcuts.Recorder` manages persistence automatically via UserDefaults |

---

## Feature Integration Details

### Feature 1: Task Count Badge

**Integration surface:** `AppDelegate` (AppKit layer only — badge is an NSStatusItem concern, not SwiftUI)

**Approach:** Composite NSImage drawn with badge overlay. NSStatusBarButton has no native badge API. Three options exist:

| Option | Mechanism | Tradeoffs |
|--------|-----------|-----------|
| A. Composite NSImage | Draw base icon + badge circle + count string onto `NSImage`; set `button.image` | Full styling control; requires redraw on every count change; works with `squareLength` or `variableLength` |
| B. `button.title` + image | Set `button.title = "3"`, `button.imagePosition = .imageLeading`, use `variableLength` | Minimal code; title and image both template-tinted; count font not customizable |
| C. NSAttributedString image | Create `NSImage` from `NSAttributedString` drawing | Overkill; same outcome as Option A |

**Recommendation: Option B (button.title + variableLength)** for v1.1. Lowest complexity, consistent with macOS system conventions (menu bar items with counts like Mail use title). Upgrade to Option A only if the design requires a red badge circle.

**Required changes to `AppDelegate`:**

1. Change `statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)` to `variableLength`
2. Add a method `func updateBadge(_ count: Int)` that sets `button.title` to `""` when `count == 0` (icon only) or `"\(count)"` when `count > 0`
3. Observe `TaskStore.incompleteCount` — `AppDelegate` must hold a reference to the `TaskStore` (or use `NotificationCenter`/`withObservationTracking`)

**State observation pattern:** `AppDelegate` currently does not hold the `TaskStore` reference — it passes it to `PanelManager` and drops it. For badge updates, `AppDelegate` needs to retain the store and use `withObservationTracking` (the `@Observable` observation API) or a simple `Timer`/notification approach.

**Simplest integration without over-engineering:**
```swift
// In AppDelegate, after PanelManager.shared.configure(with: store):
self.taskStore = store
// In setupStatusItem, after button setup:
schedulesBadgeUpdates()

private func scheduleBadgeUpdates() {
    // withObservationTracking fires once per change — re-register in onChange
    func observe() {
        withObservationTracking {
            let count = taskStore?.incompleteCount ?? 0
            DispatchQueue.main.async { self.updateBadge(count) }
        } onChange: {
            DispatchQueue.main.async { observe() }
        }
    }
    observe()
}

private func updateBadge(_ count: Int) {
    statusItem.button?.title = count > 0 ? "\(count)" : ""
}
```

**New computed property on TaskStore:**
```swift
var incompleteCount: Int {
    tasks.filter { !$0.isCompleted }.count
}
```

**Note on `variableLength`:** Switching from `squareLength` to `variableLength` means the button width expands when `title` is non-empty. When `title` is empty the button shrinks back to icon-only width. This is the intended behavior.

---

### Feature 2: Drag-to-Reorder

**Integration surface:** `TaskListView` + `TaskRowView` + `TaskStore.move()`

**Core constraint:** `TaskRowView` contains a `Toggle` (checkbox) and a `Button` (delete). SwiftUI's `.onMove` adds a drag gesture to the row; on macOS, this gesture does NOT delay clicks for `Toggle`/`Button` controls in the same way iOS does — but it does create a conflict when the user tries to initiate a drag from the checkbox area itself.

**Standard pattern (confirmed working on macOS, no `.editMode` required):**
```swift
List {
    ForEach(store.tasks) { task in
        TaskRowView(task: task)
            .listRowSeparator(.hidden)
    }
    .onMove { indices, destination in
        store.move(fromOffsets: indices, toOffset: destination)
    }
}
.listStyle(.plain)
```

**Drag handle to prevent gesture conflict:** A six-dot drag handle (`"line.3.horizontal"` SF Symbol) is added to `TaskRowView`. The handle region uses `.moveDisabled(false)` while the rest of the row uses `.moveDisabled(true)` via the `onHover` gating pattern:

```swift
// In TaskRowView.swift — add to HStack trailing side:
Image(systemName: "line.3.horizontal")
    .foregroundColor(.tertiary)
    .frame(width: 16)
    .moveDisabled(!isDragHandleHovered)  // only draggable from handle
    .onHover { isDragHandleHovered = $0 }
```

**New `@State` property in `TaskRowView`:**
```swift
@State private var isDragHandleHovered = false
```

**New method on `TaskStore`:**
```swift
func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    tasks.move(fromOffsets: source, toOffset: destination)
    persist()
}
```

**`Array.move(fromOffsets:toOffset:)` dependency note:** This method is from the `Swift` standard library but was historically surfaced via `import SwiftUI` (a quirk fixed in Swift 5.5+). Since the project targets macOS 14 / Swift 5.10, it is safe to call from `TaskStore` with only `import Foundation`.

**Persistence impact:** Drag-reorder changes the canonical order of `tasks`. Since persistence is full-array write-through (the existing pattern), `persist()` after `move` is already the correct approach — no schema changes needed. The `[Task]` JSON array is position-ordered.

---

### Feature 3: Configurable Hotkey Recorder

**Integration surface:** `SettingsView` only. Zero changes to `HotkeyService`.

**Why zero changes to HotkeyService:** `KeyboardShortcuts` already stores the user's chosen shortcut in `UserDefaults` keyed by the `Name` (`.togglePanel`). When the user records a new shortcut in `KeyboardShortcuts.Recorder`, the library automatically updates UserDefaults and the registered handler fires for the new key combination on next keypress. `HotkeyService.register()` (called once at launch) hooks the name, not a specific key combo.

**Package version note:** `Package.swift` specifies `exact: "1.10.0"`. The `KeyboardShortcuts.Recorder` SwiftUI view has been present in the library since v1.x (confirmed via library README). The `2.4.0` reference in the milestone context appears to be a target upgrade version, not the currently pinned version. The `Recorder` API is identical across 1.x and 2.x for this use case — no migration concerns.

**Required change to `SettingsView`:**

Add a second `Section` below the existing "General" section:

```swift
import KeyboardShortcuts

// Inside SettingsView.body Form:
Section {
    KeyboardShortcuts.Recorder("Toggle panel:", name: .togglePanel)
} header: {
    Text("Keyboard Shortcut")
}
```

**Frame adjustment:** The current `SettingsView` frame is `width: 400, height: 150` — sized for one section only. The new section adds approximately 60pt height. Update to `height: 230` (or switch to `fixedSize()` and let the Form size itself).

**Interaction with existing default:** The library preserves `default: .init(.space, modifiers: [.control, .option])` from the `Name` declaration. If the user has never changed the shortcut, `Recorder` shows the default. The default is shown grayed out in the recorder control as "current shortcut."

**No changes to `HotkeyService`:** The name `.togglePanel` is the stable identifier. The library handles everything else.

---

### Feature 4: Bulk-Clear Completed Tasks

**Integration surface:** `TaskStore` (new method) + new `TaskToolbarView` + `TaskListView` (hosts toolbar)

**New method on `TaskStore`:**
```swift
func clearCompleted() {
    tasks.removeAll { $0.isCompleted }
    persist()
}
```

**New component — `TaskToolbarView`:**
A slim row at the bottom of the panel below the task list. It shows a "Clear completed" button only when at least one task is completed (drives discoverability without cluttering the UI when irrelevant).

```swift
struct TaskToolbarView: View {
    @Environment(TaskStore.self) private var store
    @State private var showingConfirmation = false

    var body: some View {
        let completedCount = store.tasks.filter(\.isCompleted).count
        if completedCount > 0 {
            HStack {
                Spacer()
                Button("Clear \(completedCount) completed") {
                    showingConfirmation = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            .confirmationDialog(
                "Clear \(completedCount) completed task\(completedCount == 1 ? "" : "s")?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Completed", role: .destructive) {
                    store.clearCompleted()
                }
            }
        }
    }
}
```

**Required change to `ContentView`:**

Add `TaskToolbarView` as a fourth row in the existing `VStack`:
```swift
VStack(spacing: 0) {
    TaskInputView()
    Divider()
    TaskListView()
    Divider()
    TaskToolbarView()
}
```

**Frame impact:** `TaskToolbarView` is conditionally rendered. When no completed tasks exist it renders nothing (no height). When visible it adds ~32pt. Two options:

- **Option A (simpler):** Keep `400x300` fixed frame in `ContentView`. The toolbar overlaps the bottom of the task list slightly. Acceptable for a short toolbar row.
- **Option B (correct):** Change `ContentView` to `frame(width: 400, minHeight: 300, maxHeight: 500)` and let the list be scrollable. The panel height expands with content up to 500pt. This requires `PanelManager.show()` to use a dynamic height calculation.

**Recommendation: Option A for v1.1.** The 32pt toolbar row is slim enough to not cause significant layout shift. The existing `ContentView` fixed frame has been explicitly noted in the codebase as "deferred to Phase 3 polish." Adding toolbar within the existing 300pt is consistent with that design constraint — the list just scrolls 32pt less.

**macOS-specific: no `.onDelete` swipe.** The existing per-row delete button (trash icon in `TaskRowView`) already handles individual delete. Bulk-clear is additive. `confirmationDialog` on macOS shows as a sheet-style dialog (macOS 12+), which is correct behavior — no additional modifier needed.

---

## Updated System Overview (v1.1)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      App Entry Point                                 │
│   QuickTaskApp (@NSApplicationDelegateAdaptor AppDelegate)           │
│   NSApp.setActivationPolicy(.accessory)                              │
├─────────────────────────────────────────────────────────────────────┤
│                  System Integration Layer                            │
│  ┌────────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │
│  │  NSStatusItem      │  │  HotkeyService   │  │  AppDelegate     │ │
│  │  variableLength    │  │  (unchanged)     │  │  lifecycle       │ │
│  │  updateBadge(count)│  │                  │  │                  │ │
│  │  [NEW: badge obs.] │  │                  │  │                  │ │
│  └────────┬───────────┘  └────────┬─────────┘  └────────┬─────────┘ │
│           │ click                  │ hotkey               │          │
├───────────┴────────────────────────┴──────────────────────┴─────────┤
│                         Panel Layer                                  │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │  FloatingPanel (NSPanel — unchanged)                          │   │
│  │   NSHostingView<ContentView>.environment(store)               │   │
│  └───────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                   UI / View Layer (SwiftUI)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │TaskInputView │  │TaskListView  │  │TaskRowView   │               │
│  │ (unchanged)  │  │ [MODIFIED]   │  │ [MODIFIED]   │               │
│  │              │  │ ForEach+     │  │ drag handle  │               │
│  │              │  │ .onMove      │  │ moveDisabled │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
│                    ┌──────────────────────────────┐                  │
│                    │ TaskToolbarView [NEW]         │                  │
│                    │ "Clear N completed" +         │                  │
│                    │  confirmationDialog           │                  │
│                    └──────────────────────────────┘                  │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ SettingsView [MODIFIED]                                      │    │
│  │  Section "General": Launch at login (unchanged)              │    │
│  │  Section "Keyboard Shortcut": KeyboardShortcuts.Recorder     │    │
│  └──────────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────────┤
│                    State Layer (@Observable)                         │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │  TaskStore [MODIFIED]                                         │   │
│  │   var tasks: [Task]                                           │   │
│  │   var incompleteCount: Int  [NEW computed]                    │   │
│  │   func add / toggle / delete / clearCompleted [NEW] / move [NEW]│  │
│  └────────────────────────────┬──────────────────────────────────┘   │
│                               │                                      │
├───────────────────────────────┴──────────────────────────────────────┤
│                  Persistence Layer (unchanged)                       │
│  ┌───────────────────────┐  ┌───────────────────────────────────┐    │
│  │  TaskRepository       │  │  FileStore                        │    │
│  │  (save / loadAll)     │  │  JSON → tasks.json (atomic write) │    │
│  └───────────────────────┘  └───────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Boundaries — New vs Modified vs Unchanged

| Component | v1.1 Status | What Changes |
|-----------|-------------|--------------|
| `QuickTaskApp.swift` | Unchanged | — |
| `AppDelegate.swift` | Modified | Hold `TaskStore` ref; `variableLength`; `updateBadge`; `withObservationTracking` loop |
| `FloatingPanel.swift` | Unchanged | — |
| `PanelManager.swift` | Unchanged | — |
| `HotkeyService.swift` | Unchanged | `KeyboardShortcuts.Recorder` handles persistence; library re-registers on next keypress |
| `Task.swift` | Unchanged | — |
| `TaskStore.swift` | Modified | `+ incompleteCount`, `+ clearCompleted()`, `+ move(fromOffsets:toOffset:)` |
| `TaskRepository.swift` | Unchanged | Full-array save already handles all mutation types |
| `FileStore.swift` | Unchanged | — |
| `ContentView.swift` | Modified | Add `Divider` + `TaskToolbarView()` to `VStack` |
| `TaskInputView.swift` | Unchanged | — |
| `TaskListView.swift` | Modified | `List(store.tasks)` → `List { ForEach(store.tasks) { }.onMove { } }` |
| `TaskRowView.swift` | Modified | Add drag handle `@State`, `Image`, `moveDisabled`, `onHover` |
| `SettingsView.swift` | Modified | Add `KeyboardShortcuts.Recorder` section; increase frame height |
| `TaskToolbarView.swift` | **New** | Bulk-clear button + confirmationDialog |

---

## Data Flow — New Paths

### Badge Update Flow
```
TaskStore.tasks mutated (any add/toggle/delete/clear/move)
    ↓
@Observable notifies all observers
    ↓
withObservationTracking closure in AppDelegate fires
    ↓
AppDelegate reads taskStore.incompleteCount
    ↓
updateBadge(count) sets statusItem.button?.title
    ↓
NSStatusBar re-renders menu bar icon with count (or empty for 0)
    ↓
withObservationTracking re-registers for next change
```

### Drag-Reorder Flow
```
User hovers over drag handle in TaskRowView
    ↓
onHover fires → isDragHandleHovered = true → moveDisabled = false
    ↓
User drags row to new position
    ↓
List.onMove fires with (IndexSet, Int)
    ↓
TaskStore.move(fromOffsets:toOffset:) called
    ↓
tasks.move(fromOffsets:toOffset:) reorders in-memory array
    ↓
persist() → TaskRepository.save → FileStore writes JSON
    ↓
@Observable notifies TaskListView → List re-renders in new order
```

### Configurable Hotkey Flow
```
User opens Settings → Keyboard Shortcut section
    ↓
KeyboardShortcuts.Recorder renders recorder control
    ↓
User presses new key combination
    ↓
Library writes new shortcut to UserDefaults["togglePanel"]
    ↓
On next keypress of new combination: library fires existing onKeyUp closure
    ↓
PanelManager.shared.toggle() (unchanged)
```

### Bulk-Clear Flow
```
User sees "Clear N completed" button in TaskToolbarView (only when N > 0)
    ↓
User taps button → showingConfirmation = true
    ↓
confirmationDialog presents (macOS sheet)
    ↓
User confirms with "Clear Completed" (destructive role)
    ↓
store.clearCompleted() called
    ↓
tasks.removeAll { $0.isCompleted }
    ↓
persist() → JSON write
    ↓
@Observable notifies TaskListView (list shrinks) + AppDelegate badge (count drops)
```

---

## Build Order for v1.1

Dependencies flow bottom-up. Build in this order to avoid compilation errors on undefined symbols:

| Step | File(s) | Why This Order |
|------|---------|----------------|
| 1 | `TaskStore.swift` | Add `incompleteCount`, `clearCompleted()`, `move()`. Everything else depends on these. |
| 2 | `AppDelegate.swift` | Hold store ref + badge observer. Depends on `incompleteCount` from step 1. |
| 3 | `TaskRowView.swift` | Add drag handle state. No new dependencies, but must exist before TaskListView is changed. |
| 4 | `TaskListView.swift` | Switch to `ForEach + .onMove`. Depends on `TaskRowView` drag handle (step 3) and `TaskStore.move` (step 1). |
| 5 | `TaskToolbarView.swift` | New file. Depends on `TaskStore.clearCompleted()` (step 1). Can be built in parallel with steps 3-4. |
| 6 | `ContentView.swift` | Add `TaskToolbarView` to `VStack`. Depends on `TaskToolbarView` existing (step 5). |
| 7 | `SettingsView.swift` | Add `KeyboardShortcuts.Recorder` section + height update. No new dependencies — independent of all above. Can be built at any point. |

**Steps 5 and 7 are fully independent** — they can be implemented in any order or in parallel.

---

## Architectural Patterns — v1.1 Additions

### Pattern: withObservationTracking for AppKit badge sync

**What:** `withObservationTracking` is the `@Observable` framework's mechanism for observing changes outside of SwiftUI. It fires once when any tracked property changes, then requires re-registration.
**When to use:** Any AppKit code that needs to react to `@Observable` model changes without being a SwiftUI view.
**Trade-offs:** Must re-register on every change (recursive call pattern). Fine for a single menu bar badge; not appropriate for high-frequency updates.
**Alternative:** Use `NotificationCenter` post from `TaskStore.persist()` — simpler, avoids the re-registration ceremony, but creates an implicit coupling.

### Pattern: Conditional toolbar row (render nothing when unused)

**What:** `TaskToolbarView` returns no content when `completedCount == 0`, so it occupies zero height in the `ContentView` VStack.
**When to use:** UI elements that are only relevant sometimes (clearing 0 tasks is meaningless). Avoids always-present placeholder UI.
**Trade-offs:** The second `Divider` above `TaskToolbarView` in `ContentView` remains visible even when `TaskToolbarView` renders nothing. Wrap both the `Divider` and `TaskToolbarView` in a conditional Group, or move the `Divider` inside `TaskToolbarView`.

### Pattern: moveDisabled + onHover for targeted drag handles

**What:** Default SwiftUI drag reorder makes the entire row draggable, which competes with interactive elements. `moveDisabled(true)` on the row disables dragging by default; `moveDisabled(!isHovered)` on a specific region (the drag handle) re-enables it only over that region.
**When to use:** Any `List` row containing Toggle, Button, TextField, or other gesture-recognizing views alongside draggable content.
**Trade-offs:** The drag handle is a visible affordance — users must discover it. For users accustomed to iOS-style drag handles on macOS, this is expected. The six-dot `"line.3.horizontal"` icon is the standard macOS drag handle symbol.

---

## Anti-Patterns to Avoid

### Anti-Pattern: Observe @Observable with Combine in AppDelegate

**What people do:** Add `import Combine` and use `.sink` on a `@Published` property to drive badge updates from AppKit code.
**Why it's wrong:** `TaskStore` uses `@Observable` (not `ObservableObject`), so there are no `@Published` properties to sink on. Mixing `@Observable` and Combine requires additional boilerplate and goes against the Swift 5.9+ observation model.
**Do this instead:** Use `withObservationTracking` (native to `@Observable`) or a `NotificationCenter` post from `TaskStore.persist()`.

### Anti-Pattern: Placing .onMove on the List instead of ForEach

**What people do:** Apply `.onMove` directly to `List { TaskRowView }` without wrapping in `ForEach`.
**Why it's wrong:** `.onMove` only works on `ForEach`. The compiler will reject it on `List` with a "no matching function" error (on macOS) or silently produce no-op drag behavior (on iOS). The pattern is `List { ForEach(items) { ... }.onMove { } }`.
**Do this instead:** Always use `ForEach` inside `List` when drag reorder is needed.

### Anti-Pattern: Putting bulk-clear in the right-click context menu

**What people do:** Add "Clear completed" to the `NSMenu` in `AppDelegate.showContextMenu()` rather than in the panel UI.
**Why it's wrong:** The context menu is a system-level affordance (Settings, Quit). Task management operations belong inside the panel — the menu should not become a task management interface. It also requires threading the `TaskStore` into `AppDelegate.showContextMenu()`, creating a second pathway to TaskStore from AppKit.
**Do this instead:** `TaskToolbarView` inside the panel is the correct home for bulk-clear, keeping all task operations in the SwiftUI UI layer.

### Anti-Pattern: Changing NSStatusItem length dynamically per-update

**What people do:** Switch between `squareLength` and a computed `variableLength` value based on count, trying to "animate" the badge appearance.
**Why it's wrong:** `NSStatusItem.length` is not meant to be changed repeatedly at runtime. On some macOS versions this causes layout glitches in the menu bar, potentially shifting neighboring status items.
**Do this instead:** Set `variableLength` once at init. When count is 0, set `button.title = ""` — the button width collapses to icon-only automatically. When count > 0, set `button.title = "\(count)"` — the button expands. One property, always `variableLength`.

---

## Integration Points

### Internal Boundaries — Changed by v1.1

| Boundary | v1.0 Communication | v1.1 Change |
|----------|-------------------|-------------|
| AppDelegate ↔ TaskStore | AppDelegate created store, gave to PanelManager, no further contact | AppDelegate now retains store ref; uses `withObservationTracking` to observe `incompleteCount` |
| TaskListView ↔ TaskStore | `List(store.tasks)` direct iteration | Add `ForEach` wrapper; add `.onMove` calling `store.move()` |
| SettingsView ↔ KeyboardShortcuts | None | Add `KeyboardShortcuts.Recorder` view; library handles UserDefaults persistence internally |
| ContentView ↔ TaskStore | Indirect (store in environment, ContentView not accessing it) | Indirect still — `TaskToolbarView` accesses store via `@Environment(TaskStore.self)` |

### Internal Boundaries — Unchanged by v1.1

| Boundary | Communication |
|----------|---------------|
| HotkeyService ↔ PanelManager | Direct call `PanelManager.shared.toggle()` — unchanged |
| Views ↔ TaskStore | `@Environment(TaskStore.self)` — unchanged mechanism |
| TaskStore ↔ TaskRepository | Synchronous `repository.save(tasks)` — unchanged |
| TaskRepository ↔ FileStore | Synchronous read/write — unchanged |
| FloatingPanel ↔ SwiftUI | `NSHostingView(rootView:)` — unchanged |

---

## Sources

- KeyboardShortcuts README (sindresorhus) — `Recorder` API confirmed: https://github.com/sindresorhus/KeyboardShortcuts (HIGH confidence — official library docs)
- Swift Dev Journal — `.onMove` on macOS confirmed, `ForEach` required: https://swiftdevjournal.com/moving-list-items-using-drag-and-drop-in-swiftui-mac-apps/ (MEDIUM confidence — verified against Apple forums)
- NilCoalescing — drag handle + moveDisabled pattern for rows with interactive elements: https://nilcoalescing.com/blog/ListReorderingWhileStillBeingAbleToEditTheListItems/ (MEDIUM confidence — consistent with SwiftUI docs)
- Apple Developer Forums — `onMove` macOS behavior confirmed: https://developer.apple.com/forums/thread/736419 (HIGH confidence — official forum)
- HackingWithSwift — `confirmationDialog` on macOS 12+: https://www.hackingwithswift.com/quick-start/swiftui/how-to-let-users-delete-rows-from-a-list (MEDIUM confidence)
- Live codebase analysis — all existing component boundaries verified by reading source files directly (HIGH confidence)

---
*Architecture research for: QuickTask v1.1 feature integration — badge, drag-reorder, configurable hotkey, bulk-clear*
*Researched: 2026-02-18*
