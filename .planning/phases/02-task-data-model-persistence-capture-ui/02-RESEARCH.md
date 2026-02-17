# Phase 2: Task Data Model, Persistence, and Capture UI - Research

**Researched:** 2026-02-17
**Domain:** Swift @Observable data layer, JSON/FileManager persistence, SwiftUI TextField focus, SwiftUI checklist UI (macOS 14+)
**Confidence:** HIGH (Apple framework capabilities well-established; NSPanel+FocusState quirk documented by community; persistence pattern is industry standard)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CAPT-01 | Text field is auto-focused when panel opens | FocusState + onAppear async dispatch; NSWindowDidBecomeKeyNotification pattern as fallback |
| CAPT-02 | User types task text and presses Return to add task | TextField.onSubmit fires on Return key — standard SwiftUI API |
| CAPT-03 | Text field clears after task is added, ready for next entry | Reset @State text var to "" inside onSubmit closure |
| CAPT-04 | Tasks appear in a checklist below the text field | List + ForEach over TaskStore.tasks — standard SwiftUI List |
| TASK-01 | Each task has a checkbox to mark it complete | Toggle with .toggleStyle(.checkbox) — macOS-native, built-in |
| TASK-02 | Completed tasks show strikethrough and reduced opacity | .strikethrough(task.isCompleted) + .opacity(task.isCompleted ? 0.4 : 1.0) modifiers |
| TASK-03 | Completed tasks remain visible in the list (not auto-deleted) | Never filter list — only mutate isCompleted; completed tasks stay in tasks array |
| TASK-04 | User can delete individual tasks | Button with trash icon in TaskRowView calling TaskStore.delete(); swipeActions alternative |
| PERS-01 | Tasks persist across app quit and relaunch | Load on TaskStore init from FileStore; write-through on every mutation |
| PERS-02 | Tasks persist across system reboot | JSON file in ~/Library/Application Support/ — filesystem-backed, survives reboots |
| PERS-03 | Data stored locally as JSON in ~/Library/Application Support/ | FileManager.default.urls(.applicationSupportDirectory) + subdirectory + .atomic write |
</phase_requirements>

---

## Summary

Phase 2 builds the complete data layer and UI on top of the Phase 1 panel scaffold. The architecture flows bottom-up: `Task` model (Codable+Identifiable struct) → `FileStore` (dumb JSON I/O) → `TaskRepository` (CRUD logic) → `TaskStore` (@Observable class) → SwiftUI views. This strict dependency direction keeps views thin and the persistence layer replaceable.

The most significant technical nuance in this phase is auto-focus: SwiftUI's `@FocusState` does not fire reliably in `onAppear` on macOS, especially in an `NSPanel` that uses `.nonactivatingPanel`. The FloatingPanel already has `canBecomeKey = true` and calls `makeKey()` on show, which is a prerequisite. The additional requirement is to post focus after the run loop returns — either a `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)` inside `onAppear`, or by observing `NSWindow.didBecomeKeyNotification` in the view and setting focus there. The async dispatch approach is simpler and sufficient for this app.

The persistence story is straightforward: `JSONEncoder` + `Data.write(to:options:.atomic)` to `~/Library/Application Support/QuickTask/tasks.json`. The `.atomic` write option (temp-file-then-rename) ensures no partial writes corrupt the data file on force-quit. Directory creation must precede any write — `Application Support` sub-directories are not created automatically. The `@Observable` macro (macOS 14+) replaces `ObservableObject`/`@Published`, injected via `.environment(store)` and accessed with `@Environment(TaskStore.self)` in child views.

**Primary recommendation:** Build the four layers (Task → FileStore → TaskRepository → TaskStore) in one plan, then the input view (TaskInputView) in a second plan, then the list and row views (TaskListView + TaskRowView) in a third plan. This matches the three-plan split already documented in ROADMAP.md and matches the natural dependency order.

---

## Standard Stack

### Core (no new dependencies — all Apple frameworks)

| Component | API | Purpose | Why Standard |
|-----------|-----|---------|--------------|
| Swift Codable | `Codable` protocol alias (`Encodable + Decodable`) | Serialize/deserialize Task to/from JSON | Zero boilerplate, built into Swift since 4.0 |
| JSONEncoder / JSONDecoder | `Foundation` | Encode `[Task]` to `Data` and back | No dependencies, well-tested, works with all `Codable` types |
| FileManager | `Foundation` | Resolve `applicationSupportDirectory`, create sub-dirs | Standard macOS/iOS file access; sandbox-safe |
| @Observable macro | `Observation` framework (macOS 14+) | Replace `ObservableObject` + `@Published` | Fine-grained property observation; no Combine import; simpler syntax |
| @FocusState | SwiftUI (iOS 15+ / macOS 12+) | Programmatic TextField focus | Native SwiftUI API; no UIKit/AppKit workaround needed |
| Toggle / .toggleStyle(.checkbox) | SwiftUI | Native macOS checkbox | macOS-only, native appearance; no custom draw code |
| .strikethrough() | SwiftUI (Text modifier) | Strike completed task text | Single modifier; accepts Bool |
| .onSubmit | SwiftUI | Handle Return key in TextField | Fires on Return; standard pattern for quick-add inputs |

### Supporting Libraries (already in Package.swift from Phase 1)

| Library | Version | Phase 1 Decision | Phase 2 Use |
|---------|---------|-----------------|-------------|
| KeyboardShortcuts | 1.10.0 (Package.swift shows `exact: "1.10.0"`) | Global hotkey | No new use in Phase 2 |
| Defaults | Not yet added to Package.swift | Planned for Phase 3 | Not needed in Phase 2 |

**No new SPM dependencies are needed for Phase 2.** All required functionality is in Apple's standard frameworks.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@Observable` | `ObservableObject` + `@Published` | `ObservableObject` works on macOS 11+; `@Observable` is macOS 14+ but already the project's minimum target. `@Observable` is preferred: no Combine import, more granular view updates |
| `FileManager` + JSON | UserDefaults / `@AppStorage` | UserDefaults is wrong for structured data (not designed for arrays, no atomic writes, harder to debug). JSON file is the correct pattern |
| `List` | `ScrollView + ForEach` | `List` is lazily rendered by default (better for large lists), provides platform-native row styling, and `swipeActions` come free. Use `List` |
| `.toggleStyle(.checkbox)` | Custom `ToggleStyle` | Built-in checkbox matches macOS HIG exactly. Use it unless custom visual design is required |

---

## Architecture Patterns

### Recommended Project Structure (additions to Phase 1)

```
QuickTask/Sources/
├── App/
│   ├── QuickTaskApp.swift         # (Phase 1 — inject TaskStore via .environment here)
│   └── AppDelegate.swift          # (Phase 1 — no changes)
├── Panel/
│   ├── FloatingPanel.swift        # (Phase 1 — no changes)
│   └── PanelManager.swift         # (Phase 1 — no changes needed)
├── Hotkey/
│   └── HotkeyService.swift        # (Phase 1 — no changes)
├── Model/
│   └── Task.swift                 # NEW: Codable + Identifiable struct
├── Persistence/
│   ├── FileStore.swift            # NEW: JSON read/write to disk
│   └── TaskRepository.swift       # NEW: CRUD logic coordinating FileStore
├── Store/
│   └── TaskStore.swift            # NEW: @Observable, single source of truth
└── Views/
    ├── ContentView.swift          # REPLACE: was placeholder; becomes root layout
    ├── TaskInputView.swift        # NEW: TextField + auto-focus + onSubmit
    ├── TaskListView.swift         # NEW: List + ForEach over tasks
    └── TaskRowView.swift          # NEW: checkbox + strikethrough + delete button
```

### Pattern 1: Task Model — Codable Identifiable Value Type

**What:** A plain Swift struct conforming to `Codable` and `Identifiable`. Value type (struct) keeps state reasoning simple — mutations produce new values, no hidden aliasing.
**When to use:** Any time you have simple flat data with no relationships.

```swift
// Source: Apple developer docs — Codable, Identifiable
import Foundation

struct Task: Codable, Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
}
```

Key decisions:
- `id` and `createdAt` are `let` — they never change after creation
- `title` and `isCompleted` are `var` — they can be mutated
- No `completedAt` date in Phase 2 (Phase 3+ enhancement if needed)

### Pattern 2: FileStore — Dumb JSON I/O

**What:** A type (struct or final class) responsible only for encoding/decoding and reading/writing. No business logic. Returns `[Task]` or throws.

```swift
// Source: Apple developer docs — FileManager, JSONEncoder
import Foundation

struct FileStore {
    private let fileURL: URL

    init() {
        // Get ~/Library/Application Support/
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("QuickTask", isDirectory: true)

        // Create the directory if it doesn't exist.
        // CRITICAL: Application Support sub-directories are NOT created automatically.
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true,
            attributes: nil
        )

        self.fileURL = appSupport.appendingPathComponent("tasks.json")
    }

    func load() -> [Task] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Task].self, from: data)) ?? []
    }

    func save(_ tasks: [Task]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        // .atomic: writes to temp file, then renames — no partial writes on force-quit
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

### Pattern 3: TaskRepository — CRUD Business Logic

**What:** Encapsulates add/toggle/delete operations. Owns a `FileStore` instance. Called by `TaskStore`. Views never call this directly.

```swift
// Source: architecture established in Phase 1 research (ARCHITECTURE.md)
import Foundation

struct TaskRepository {
    private let store = FileStore()

    func loadAll() -> [Task] {
        store.load()
    }

    func save(_ tasks: [Task]) {
        store.save(tasks)
    }
}
```

`TaskRepository` may seem thin — that is intentional. It is the abstraction boundary between `TaskStore` and `FileStore`. If the storage backend changes (e.g., SwiftData in Phase 4+), only `TaskRepository` changes; `TaskStore` and views remain untouched.

### Pattern 4: TaskStore — @Observable Single Source of Truth

**What:** `@Observable` class. Owns `[Task]` array. Exposes mutation methods. Writes to disk on every mutation. Views never call FileStore directly.

```swift
// Source: Apple Observation framework docs, macOS 14+
import Foundation
import Observation

@Observable
final class TaskStore {
    var tasks: [Task] = []
    private let repository = TaskRepository()

    init() {
        tasks = repository.loadAll()
    }

    func add(title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        tasks.append(Task(title: title))
        persist()
    }

    func toggle(_ task: Task) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].isCompleted.toggle()
        persist()
    }

    func delete(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    private func persist() {
        repository.save(tasks)
    }
}
```

**Injection pattern** (in QuickTaskApp.swift):
```swift
// Source: Apple docs — environment modifier with @Observable
@main
struct QuickTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // @State (not @StateObject) is correct for @Observable classes
    @State private var taskStore = TaskStore()

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

**Problem:** `QuickTaskApp` uses a `Settings { EmptyView() }` scene; the real UI lives in an NSPanel created by `PanelManager`. The `taskStore` must be passed to `ContentView` when the panel is created in `PanelManager`. Use `NSHostingView(rootView: ContentView().environment(taskStore))`.

This requires `PanelManager` to hold a reference to `TaskStore`, or `TaskStore` to be a singleton. The cleanest approach is to make `PanelManager` accept a `TaskStore` on construction, initialized from `AppDelegate`:

```swift
// In AppDelegate.applicationDidFinishLaunching:
let store = TaskStore()
PanelManager.shared.configure(with: store)
HotkeyService.shared.register()
```

```swift
// In PanelManager:
private var taskStore: TaskStore?

func configure(with store: TaskStore) {
    self.taskStore = store
    // Rebuild panel now that we have the store
    panel = FloatingPanel(rootView: ContentView().environment(store))
}
```

Alternatively: make `TaskStore` a singleton (`static let shared = TaskStore()`). Given this app has exactly one task list and no testing requirements for now, a singleton is acceptable and simpler.

**In child views:**
```swift
// Source: Apple docs — @Environment with @Observable
struct TaskInputView: View {
    @Environment(TaskStore.self) private var store
    // ...
}
```

### Pattern 5: TextField Auto-Focus (Critical Nuance)

**What:** Auto-focus the TextField every time the panel is shown, without a click.

**The problem:** SwiftUI's `@FocusState` set in `onAppear` is unreliable in `NSPanel` contexts. `onAppear` fires when the SwiftUI view tree is first built, but NSPanel with `.nonactivatingPanel` may not have become the key window yet at that moment. Setting `@FocusState` before the window is key has no effect.

**Reliable approach — two-step:**

Step 1: `onAppear` with a short async dispatch (the panel was pre-created and may already be in the hierarchy, so `onAppear` may not fire on re-show). The correct trigger for "panel just became visible" is `NSWindow.didBecomeKeyNotification`.

Step 2: Observe `NSWindow.didBecomeKeyNotification` in the view:

```swift
// Source: Apple docs — NotificationCenter, NSWindow notifications
struct TaskInputView: View {
    @Environment(TaskStore.self) private var store
    @FocusState private var inputFocused: Bool
    @State private var text = ""

    var body: some View {
        TextField("Add a task...", text: $text)
            .focused($inputFocused)
            .onSubmit { submitTask() }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSWindow.didBecomeKeyNotification
                )
            ) { _ in
                // Small dispatch allows the run loop to finish making window key
                // before we request first responder
                DispatchQueue.main.async {
                    inputFocused = true
                }
            }
    }

    private func submitTask() {
        store.add(title: text)
        text = ""
        // Re-focus after submit so next task can be typed immediately
        DispatchQueue.main.async { inputFocused = true }
    }
}
```

**Why `NSWindow.didBecomeKeyNotification` instead of `onAppear`:**
- `onAppear` fires once when the view is first created, NOT on subsequent panel re-shows (because FloatingPanel reuses the same NSHostingView — it calls `orderOut`, not `close`)
- `NSWindow.didBecomeKeyNotification` fires every time the panel becomes key, including re-shows
- The `DispatchQueue.main.async` ensures the window is fully key before attempting first responder change

**Alternative (simpler but works only once):** `onAppear` with `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)`. This only auto-focuses on the first show. Use `NSWindow.didBecomeKeyNotification` for reliable re-focus on every open.

### Pattern 6: TaskRowView — Checkbox, Strikethrough, Opacity, Delete

```swift
// Source: Apple docs — Toggle.toggleStyle(.checkbox), .strikethrough, .opacity
struct TaskRowView: View {
    @Environment(TaskStore.self) private var store
    let task: Task

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { task.isCompleted },
                set: { _ in store.toggle(task) }
            )) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .opacity(task.isCompleted ? 1.0 : 1.0) // Text opacity handled by row
            }
            .toggleStyle(.checkbox)  // macOS-native checkbox — macOS only

            Spacer()

            Button {
                store.delete(task)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete task")
        }
        .opacity(task.isCompleted ? 0.4 : 1.0)  // Fade entire row when complete
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
    }
}
```

Key decisions:
- `.toggleStyle(.checkbox)` is macOS-only (confirmed by Apple docs: `CheckboxToggleStyle` is `macOS` only)
- Animate the entire row opacity, not just the text — this is more visually distinct
- `.strikethrough(task.isCompleted)` on `Text` provides additional visual cue
- Delete button is `.buttonStyle(.plain)` to avoid default button chrome in a List row

### Pattern 7: TaskListView — List + ForEach

```swift
// Source: Apple docs — List, ForEach with Identifiable
struct TaskListView: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        List(store.tasks) { task in
            TaskRowView(task: task)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}
```

Use `List` over `ScrollView + ForEach` because:
- `List` is lazy by default — only renders visible rows
- Native macOS row styling
- `swipeActions` (Phase 4 convenience) come free

### Anti-Patterns to Avoid

- **Views calling FileStore directly:** Views call `TaskStore` only. FileStore is a private implementation detail of the persistence layer.
- **Storing tasks in UserDefaults:** Not designed for structured arrays; no atomic writes; 4MB plist size limit. Use JSON in Application Support.
- **Using `onAppear` alone for auto-focus in a reusable panel:** `onAppear` fires once. Use `NSWindow.didBecomeKeyNotification` for reliable re-focus on every open.
- **Using `@StateObject` with `@Observable`:** `@Observable` classes are used with `@State` (at the owner site) and `@Environment` (in child views). `@StateObject` is for `ObservableObject` only.
- **Filtering completed tasks out of the list:** TASK-03 explicitly requires completed tasks to remain visible. Never filter — only control visual styling.
- **Writing JSON on the main thread without `.atomic`:** Without `.atomic`, a force-quit mid-write produces a truncated/corrupt file. Always use `data.write(to:options:.atomic)`.
- **Forgetting to create the Application Support subdirectory:** `FileManager` does NOT auto-create `~/Library/Application Support/QuickTask/`. Call `createDirectory(at:withIntermediateDirectories:true)` before first write.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Checkbox UI | Custom drawn checkbox | `.toggleStyle(.checkbox)` | Built-in macOS native checkbox, HIG-compliant, accessibility-ready |
| JSON serialization | Manual string building | `JSONEncoder` + `Codable` | Handles Date, UUID, nested types, escaping, edge cases automatically |
| Atomic file write | Read-modify-write pattern | `Data.write(to:options:.atomic)` | OS-level temp-then-rename; safe against force-quit mid-write |
| Observable state | Manual `willSet` + `didSet` + notification posting | `@Observable` macro | Automatic synthesis; compile-time safe; more granular than `@Published` |
| Strikethrough animation | Custom NSAttributedString | `.strikethrough()` SwiftUI modifier | Single modifier on `Text`, accepts Bool; animated by SwiftUI |
| Focus management | `NSTextField.becomeFirstResponder()` | `@FocusState` + `.focused()` | Works within SwiftUI responder chain correctly |

**Key insight:** Every problem in this phase has a first-party Apple solution. No third-party libraries are needed. The implementation risk in Phase 2 is pattern selection and wiring order, not library complexity.

---

## Common Pitfalls

### Pitfall 1: onAppear Does Not Re-Fire on NSPanel Re-Show

**What goes wrong:** Text field does not auto-focus when the user opens the panel a second time. First open works; subsequent opens don't.

**Why it happens:** `PanelManager` calls `panel.orderOut(nil)` to hide and `panel.orderFrontRegardless()` to show — this is NOT creating/destroying the view. `onAppear` fires when the SwiftUI view is inserted into the hierarchy, which happens exactly once (on first show with the lazy panel). `onAppear` does NOT fire when an already-initialized view's window is re-shown.

**How to avoid:** Use `NotificationCenter` to observe `NSWindow.didBecomeKeyNotification` in the view, and set `@FocusState` in that handler (with a `DispatchQueue.main.async` dispatch to ensure window is fully key).

**Warning signs:** Auto-focus works on first panel open but not on second.

---

### Pitfall 2: Application Support Sub-Directory Not Created

**What goes wrong:** First launch fails to save tasks. App crashes or silently fails on first `data.write(to:fileURL)` because `~/Library/Application Support/QuickTask/` does not exist.

**Why it happens:** Unlike `Documents`, `Application Support` sub-directories for your app are not created automatically. `FileManager` only creates the `Application Support` parent; your app-specific subdirectory must be created explicitly.

**How to avoid:** In `FileStore.init()`, always call `createDirectory(at:withIntermediateDirectories:true)` before computing `fileURL`. The `try?` discards "already exists" errors safely.

**Warning signs:** First-launch crash in `data.write(to:)`. File not present at expected path after first run.

---

### Pitfall 3: @Observable Injected Wrong Way Into NSHostingView

**What goes wrong:** Views crash at runtime with "No observable object of type TaskStore found" or similar, because `TaskStore` was never injected into the SwiftUI environment.

**Why it happens:** The `FloatingPanel` creates an `NSHostingView(rootView: ContentView())`. If `ContentView` or its children use `@Environment(TaskStore.self)`, the environment value must be set on the root view passed to `NSHostingView`. It is not automatically available from the SwiftUI App's environment because `NSHostingView` creates an isolated SwiftUI environment.

**How to avoid:** Always pass the store at the hosting view creation site:
```swift
NSHostingView(rootView: ContentView().environment(taskStore))
```

The `taskStore` instance must be created before or during `PanelManager` initialization and passed in.

**Warning signs:** Runtime crash with message about missing environment value; works in Previews but not in the running app.

---

### Pitfall 4: @StateObject Used with @Observable

**What goes wrong:** Compiler warning or subtle correctness issue: the `TaskStore` reinitializes on every view rebuild because `@State` with `@Observable` behaves differently from `@StateObject`.

**Why it happens:** `@StateObject` and `@Observable` are from two different observation systems. When `@Observable` classes are stored at a parent scope with `@State`, SwiftUI correctly preserves them for the view's lifetime. But if you accidentally use `@StateObject` with an `@Observable` type (which does not conform to `ObservableObject`), the compiler will error. The risk is using `@ObservedObject` where `@Environment` is expected.

**How to avoid:**
- Owner site: `@State private var store = TaskStore()` (not `@StateObject`)
- Child views: `@Environment(TaskStore.self) private var store` (not `@EnvironmentObject`)

---

### Pitfall 5: Forgetting .atomic on File Writes

**What goes wrong:** Task data is corrupted after a force-quit mid-save. On next launch, `JSONDecoder` fails to decode the partial file and returns an empty task list, silently discarding all tasks.

**Why it happens:** Without `.atomic`, `Data.write(to:)` writes bytes incrementally to the target file. A force-quit at any point during writing leaves a partial/corrupt file.

**How to avoid:** Always use `data.write(to: fileURL, options: .atomic)`. The `.atomic` option writes to a temporary file and renames it to the target only after the write completes. On force-quit, either the old file is intact or the new file is intact — never a partial file.

---

### Pitfall 6: Empty Title Guard Missing

**What goes wrong:** User presses Return on an empty TextField. An empty-title task is added to the list.

**Why it happens:** `onSubmit` fires whenever the user presses Return, regardless of whether the text field is empty.

**How to avoid:** In `TaskStore.add(title:)`, guard against whitespace-only strings:
```swift
guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
```

---

## Code Examples

Verified patterns from official sources and prior research:

### Task Model (complete)

```swift
// Source: Apple docs — Codable, Identifiable, Foundation
import Foundation

struct Task: Codable, Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
}
```

### FileStore (complete)

```swift
// Source: Apple docs — FileManager.urls, Data.write, JSONEncoder/JSONDecoder
import Foundation

struct FileStore {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("QuickTask", isDirectory: true)

        // MUST create directory — not created automatically
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true,
            attributes: nil
        )

        self.fileURL = appSupport.appendingPathComponent("tasks.json")
    }

    func load() -> [Task] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Task].self, from: data)) ?? []
    }

    func save(_ tasks: [Task]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: fileURL, options: .atomic)  // .atomic = safe against force-quit
    }
}
```

### TaskStore injection into NSHostingView

```swift
// In PanelManager or AppDelegate:
let store = TaskStore()
let hostingView = NSHostingView(rootView: ContentView().environment(store))
panel.contentView = hostingView
```

### TextField with auto-focus via NSWindow notification

```swift
// Source: Apple docs — FocusState, NotificationCenter, NSWindow.didBecomeKeyNotification
import SwiftUI
import AppKit

struct TaskInputView: View {
    @Environment(TaskStore.self) private var store
    @FocusState private var inputFocused: Bool
    @State private var text = ""

    var body: some View {
        TextField("Add a task...", text: $text)
            .textFieldStyle(.plain)
            .focused($inputFocused)
            .onSubmit {
                store.add(title: text)
                text = ""
                DispatchQueue.main.async { inputFocused = true }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSWindow.didBecomeKeyNotification
                )
            ) { _ in
                DispatchQueue.main.async { inputFocused = true }
            }
    }
}
```

### Checkbox row with strikethrough and opacity

```swift
// Source: Apple docs — Toggle, CheckboxToggleStyle, .strikethrough, .opacity, .animation
struct TaskRowView: View {
    @Environment(TaskStore.self) private var store
    let task: Task

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { task.isCompleted },
                set: { _ in store.toggle(task) }
            )) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
            }
            .toggleStyle(.checkbox)

            Spacer()

            Button {
                store.delete(task)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .opacity(task.isCompleted ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
    }
}
```

### ContentView root layout (replaces placeholder)

```swift
// Source: Phase 1 ContentView structure + Phase 2 requirements
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            TaskInputView()
                .padding()

            Divider()

            TaskListView()
        }
        .frame(width: 400, height: 300)
        .background(.regularMaterial)
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ObservableObject` + `@Published` + Combine | `@Observable` macro | macOS 14 (WWDC 2023) | No Combine import; granular updates; `@State` replaces `@StateObject`; `@Environment` replaces `@EnvironmentObject` |
| `@EnvironmentObject` | `@Environment(MyType.self)` | macOS 14 | Type-safe environment without `ObservableObject` conformance requirement |
| `@StateObject` at owner | `@State` at owner | macOS 14 | `@StateObject` is for `ObservableObject`; `@State` for `@Observable` |
| `UserDefaults` for small data | JSON in Application Support | Always best practice, now well-documented | Correct tool for structured app data |
| `onAppear` for focus | `NSWindow.didBecomeKeyNotification` | Panel reuse pattern | Fires on every re-show; `onAppear` fires only once for reused panels |

**Deprecated/outdated:**
- `ObservableObject` + `@Published`: Still valid and works, but `@Observable` is the macOS 14+ standard. This project already targets macOS 14, so use `@Observable`.
- `@StateObject` with `@Observable` types: Compile error — not applicable.
- `onCommit` on TextField: Replaced by `onSubmit` (available since iOS 15 / macOS 12).

---

## Open Questions

1. **TaskStore singleton vs. environment injection via PanelManager**
   - What we know: `QuickTaskApp` uses `Settings { EmptyView() }` — there is no SwiftUI window scene to inject `@State var store` into via the normal App lifecycle. The NSPanel is created by `PanelManager`, which is an AppKit singleton.
   - What's unclear: The cleanest way to wire `TaskStore` into `PanelManager.panel` without a singleton.
   - Recommendation: Make `TaskStore` a singleton (`static let shared = TaskStore()`). It is the only task store; the app has one list. Create it in `AppDelegate.applicationDidFinishLaunching` and pass it to `PanelManager.configure(with:)`. The planner should pick one approach and document the decision.

2. **Panel height: fixed 300pt or dynamic to content?**
   - What we know: Phase 1 set panel and ContentView to 400x300. A task list that grows will overflow a fixed 300pt height.
   - What's unclear: Whether the panel should grow dynamically or scroll within the fixed frame.
   - Recommendation: Keep the panel at 400x300 (fixed) with `List` scrolling within the available space. Dynamic sizing is a Phase 3 polish concern. This avoids NSPanel size-change complications in Phase 2.

3. **Sort order for tasks**
   - What we know: Tasks are appended in insertion order. Completed tasks are not filtered out.
   - What's unclear: Should completed tasks sort to the bottom? Not specified in requirements.
   - Recommendation: Display tasks in insertion order (no sort). Completed tasks stay in place. Sorting is a Phase 4 enhancement if requested.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Docs — `Codable`, `JSONEncoder`, `JSONDecoder` (Foundation framework)
- Apple Developer Docs — `@Observable` macro, Observation framework (macOS 14+, WWDC 2023)
- Apple Developer Docs — `FocusState`, `focused()`, `onSubmit` modifiers (SwiftUI)
- Apple Developer Docs — `CheckboxToggleStyle` (SwiftUI, macOS-only)
- Apple Developer Docs — `NSWindow.didBecomeKeyNotification` (AppKit)
- Apple Developer Docs — `FileManager.urls(for:in:)`, `Data.write(to:options:)` (Foundation)
- Phase 1 ARCHITECTURE.md — established build order, data layer design, FileStore/TaskRepository/TaskStore pattern
- Phase 1 STACK.md — established `@Observable` decision, JSON + FileManager decision, no Combine

### Secondary (MEDIUM confidence)
- Jesse Squires, "SwiftUI @Observable macro is not a drop-in replacement for ObservableObject" (Sep 2024) — `@State` vs `@StateObject`, memory concerns: https://www.jessesquires.com/blog/2024/09/09/swift-observable-macro/
- Hacking With Swift — "Sharing @Observable objects through SwiftUI environment" — `@Environment(Type.self)` pattern: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
- Hacking With Swift — "How to make a TextField have default focus" — `defaultFocus()` on macOS: https://www.hackingwithswift.com/quick-start/swiftui/how-to-make-a-textfield-or-texteditor-have-default-focus
- Swift With Majid — "Storing Codable structs on the disk" — `Data.write(to:options:.atomic)` pattern: https://swiftwithmajid.com/2019/05/22/storing-codable-structs-on-the-disk/
- Apple Developer Forums — `FocusState` in `NSPanel` context, `onAppear` timing issues: https://developer.apple.com/forums/thread/681941

### Tertiary (LOW confidence — verify before implementing if in doubt)
- Community consensus from multiple WebSearch results: `DispatchQueue.main.async` dispatch needed when setting `@FocusState` programmatically in `NSPanel` context (not a single authoritative source; multiple practitioners report this)
- Community consensus: `NSWindow.didBecomeKeyNotification` more reliable than `onAppear` for panel re-show focus (reported in multiple developer forums; aligns with Apple NSPanel docs on re-show behavior)

---

## Metadata

**Confidence breakdown:**
- Task model (Codable + Identifiable struct): HIGH — standard Swift since Swift 4
- FileStore (JSONEncoder + FileManager + .atomic): HIGH — Apple-documented pattern
- TaskRepository / TaskStore layering: HIGH — established in Phase 1 research, confirmed by multiple sources
- @Observable injection via NSHostingView: MEDIUM — NSHostingView's environment isolation is documented; the `.environment(store)` at rootView creation is the correct pattern but not officially spelled out for NSPanel context
- TextField auto-focus (NSWindow.didBecomeKeyNotification): MEDIUM — community-reported as reliable; official docs don't explicitly address NSPanel+FocusState; the approach is logically correct
- SwiftUI List + ForEach + CheckboxToggleStyle: HIGH — Apple-documented

**Research date:** 2026-02-17
**Valid until:** 2026-09-17 (stable Apple frameworks; 6-month estimate for standard APIs)
